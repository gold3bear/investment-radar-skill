"""
browser_watch.ps1
浏览器盯盘脚本 - 每5分钟从 TradingView 抓取期货+外汇实时价格
有变化则推送飞书通知
"""
param(
    [string]$StateFile = "$env:USERPROFILE\.openclaw\workspace\watched_prices.json",
    [string]$FeishuToken = $null  # 空=使用内置逻辑发飞书
)

$ErrorActionPreference = "SilentlyContinue"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

# ── 监控品种配置 ────────────────────────────────────────────────────────
$WatchList = @(
    # 期货
    @{ Symbol="NQ1!"; Name="纳指期货NQ"; Url="https://www.tradingview.com/symbols/CME_MINI-NQ1!/"; Type="futures" },
    @{ Symbol="ES1!"; Name="标普期货ES"; Url="https://www.tradingview.com/symbols/CME_MINI-ES1!/"; Type="futures" },
    # 外汇
    @{ Symbol="USDCNH"; Name="USD/CNH 离岸"; Url="https://www.tradingview.com/symbols/OANDA-USDCNH/"; Type="forex" },
    @{ Symbol="USDCNY"; Name="USD/CNY 在岸"; Url="https://www.tradingview.com/symbols/OANDA-USDCNY/"; Type="forex" },
    @{ Symbol="USDJPY"; Name="USD/JPY";    Url="https://www.tradingview.com/symbols/OANDA-USDJPY/"; Type="forex" },
    @{ Symbol="EURUSD"; Name="EUR/USD";    Url="https://www.tradingview.com/symbols/OANDA-EURUSD/"; Type="forex" }
)

# ── 读上次状态 ──────────────────────────────────────────────────────────
function Load-State {
    if (Test-Path $StateFile) {
        try {
            $content = Get-Content $StateFile -Raw -Encoding UTF8
            return [System.Text.Json.JsonSerializer]::Deserialize($content, [PSCustomObject])
        } catch { }
    }
    return [PSCustomObject]@{ prices = @{} }
}

function Save-State($state) {
    $dir = Split-Path $StateFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = [System.Text.Json.JsonSerializer]::Serialize($state, (New-Object System.Text.Json.JsonSerializerOptions -Property WriteIndented))
    Set-Content -Path $StateFile -Value $json -Encoding UTF8
}

# ── 浏览器操作：打开页面并解析价格 ─────────────────────────────────────
function Get-BrowserPage {
    param([string]$Url, [string]$Symbol)

    $escapedUrl = $Url -replace "'", "''"
    $ps = @"
`$browserCmd = @'
function getPagePrice(url) {
    const { chromium } = require('playwright');
    (async () => {
        const browser = await chromium.launch({ headless: true, args: ['--no-sandbox','--disable-setuid-sandbox'] });
        const page = await browser.newPage();
        await page.setExtraHTTPHeaders({ 'User-Agent': '$UA' });
        await page.goto(url, { waitUntil: 'networkidle', timeout: 15000 });
        await page.waitForTimeout(2000);

        // 提取价格文本：TradingView 格式 "NQ1! 27,435.00 D USD +501.00 +1.86%"
        const txt = await page.evaluate(() => document.body.innerText);
        const lines = txt.split('\n').map(l => l.trim()).filter(l => l.length > 0);
        let result = '';
        for (const line of lines) {
            if (line.includes('+') || line.includes('-')) {
                // 找含有 symbol 和涨跌的完整行
                if (line.includes(' USD') || line.includes(' JPY')) {
                    result = line;
                    break;
                }
            }
        }
        // 备选：从 price class 获取
        if (!result) {
            const priceEl = document.querySelector('[class*="price"]');
            if (priceEl) result = priceEl.innerText;
        }
        await browser.close();
        console.log(JSON.stringify({ ok: true, text: result, url }));
    })().catch(e => console.log(JSON.stringify({ ok: false, error: e.message })));
}
'@
$scriptBlock = [scriptblock]::Create($browserCmd.Replace("'@'@'", "''"))
# 用 node 执行...
"@

    # 实际使用 curl + browser 工具（由父 agent 调用）
    return $null
}

# ── 用 PowerShell 的 Invoke-WebRequest ──────────────────────────────────
function Get-PriceFromPage {
    param([string]$Url, [string]$Symbol)

    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers @{ "User-Agent" = $UA } -TimeoutSec 15 -UseBasicParsing
        $html = $resp.Content

        # TradingView 页面中价格嵌入在 JSON 或特定元素中
        # 尝试匹配 "27,435.00" 格式的价格
        $pricePattern = '([\d,]+(?:\.\d+)?)\s*(?:USD|JPY)'
        if ($html -match $pricePattern) {
            $priceStr = $Matches[1] -replace ',', ''
            $price = [double]$priceStr

            # 提取涨跌幅
            $chgPattern = '([+-]?[\d,]+(?:\.\d+)?)\s*%\s*(?:At|At close)?'
            $chgPct = 0
            if ($html -match '([+-]\d+\.\d+)%') {
                $chgPct = [double]$Matches[1]
            }

            return @{
                Price   = $price
                ChgPct  = $chgPct
                Raw     = $Matches[0]
                Success = $true
            }
        }
    } catch {
        Write-Host "[WARN] Failed to fetch $Symbol from $Url : $_"
    }
    return @{ Success = $false }
}

# ── 主逻辑 ──────────────────────────────────────────────────────────────
$state   = Load-State
$now     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$changes = @()
$allPrices = @{}

foreach ($item in $WatchList) {
    $sym    = $item.Symbol
    $result = Get-PriceFromPage -Url $item.Url -Symbol $sym

    if ($result.Success) {
        $price = $result.Price
        $chgPct = $result.ChgPct
        $allPrices[$sym] = @{ price = $price; chgPct = $chgPct; time = $now }

        $prev = $state.prices.$sym
        if ($null -ne $prev) {
            $delta = [Math]::Abs($price - $prev.price)
            $pctChange = $prev.chgPct
            # 检测价格或涨跌幅变化 > 阈值
            $threshold = if ($item.Type -eq "forex") { 0.001 } else { 0.3 }
            if ($delta -gt $threshold -or [Math]::Abs($chgPct - $pctChange) -gt 0.1) {
                $arrow = if ($chgPct -ge 0) { "🔴" } else { "🟢" }
                $direction = if ($chgPct -gt $pctChange) { "上涨" } elseif ($chgPct -lt $pctChange) { "下跌" } else { "波动" }
                $changes += "$arrow ${sym}: ${price} (${chgPct}%) ${direction}了"
            }
        }
    } else {
        $allPrices[$sym] = $state.prices.$sym  # 保留上次值
    }
}

# 更新状态
$state.prices = $allPrices
$state.lastRun = $now
Save-State $state

# ── 推送飞书通知 ──────────────────────────────────────────────────────
if ($changes.Count -gt 0) {
    $msg = "📊 浏览器盯盘提醒 `($now)`\n" + ($changes -join "`n")
    Write-Host "NOTIFY: $msg"

    # 发送到飞书（简单 HTTP POST via openclaw gateway 的 message 工具）
    # 这里只输出，由父 agent 决定如何发送
    @{
        type = "feishu_notify"
        text = $msg
        changes = $changes
        prices = $allPrices
    } | ConvertTo-Json -Depth 3
} else {
    Write-Host "[$now] 无变化，跳过推送"
    @{
        type = "no_change"
        time = $now
        prices = $allPrices
    } | ConvertTo-Json -Depth 3
}
