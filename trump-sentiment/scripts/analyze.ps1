# trump-sentiment-analysis.ps1
# Trump 舆情分析 — 处理层脚本
# 调用方（agent/cron）负责用 web_search 填充数据，本脚本做：去重 + 评分 + 格式化
param(
    [string]$Data = "",
    [string]$File = "",
    [switch]$Test
)

$ERROR_ACTION = "Stop"

# ── Scoring ─────────────────────────────────────────────────────
function Score-Result($title, $desc, $url) {
    $score = 0; $cat = "other"; $sig = "低"; $kwlist = @()
    $t = "$title $desc".ToLower()
    
    # Breaking news
    if ($title -match "BREAKING|🚨|urgent|突发") { $score += 3; $kwlist += "突发" }
    
    # Source authority bonus — does NOT override category
    if ($url -match "bloomberg|reuters") { $score += 3; $kwlist += "Bloomberg/路透" }
    elseif ($url -match "foxnews|fox\.com") { $score += 3; $kwlist += "Fox News" }
    elseif ($url -match "wsj|financialtimes|ft\.com|nytimes|economist") { $score += 2; $kwlist += "权威媒体" }
    elseif ($url -match "cnbc|cnn|abc news|nbc") { $score += 1; $kwlist += "主流媒体" }
    
    # Content keywords — THESE set the category
    if ($t -match "bitcoin|btc|ethereum|crypto|加密|coinbase") { $score += 2; $kwlist += "BTC"; $cat = "crypto" }
    if ($t -match "oil|brent|wti|gasoline|energy|petroleum|原油|油价") { $score += 2; $kwlist += "能源"; $cat = "commodity" }
    if ($t -match "gold|silver|xau|黄金") { $score += 2; $kwlist += "黄金"; $cat = "commodity" }
    if ($t -match "stock|s&p 500|nasdaq|market futures|dow|标普|美股") { $score += 2; $kwlist += "美股"; $cat = "equity" }
    if ($t -match "trump|iran|war|strike|military|israel|houthi|tehran") { $score += 3; $kwlist += "Trump地缘"; if ($cat -eq "other") { $cat = "macro" } }
    if ($t -match "tariff|tariffs|关税") { $score += 3; $kwlist += "宏观TARIFF"; if ($cat -eq "other") { $cat = "macro" } }
    if ($t -match "deal|ceasefire|negotiate|talks|peace|协议|停火") { $score += 2; $kwlist += "停火协议"; if ($cat -eq "other") { $cat = "macro" } }
    if ($t -match "fed|federal reserve|interest rate|inflation|cpi|降息|利率") { $score += 2; $kwlist += "宏观政策"; if ($cat -eq "other") { $cat = "macro" } }
    if ($t -match "bond|treasury|yield|10-year|美债") { $score += 2; $kwlist += "债券"; if ($cat -eq "other") { $cat = "macro" } }
    if ($t -match "china|chinese|大陆|中概") { $score += 1; $kwlist += "宏观CHINA"; if ($cat -eq "other") { $cat = "macro" } }
    if ($t -match "polymarket|odds|betting") { $score += 1; $kwlist += "Polymarket"; if ($cat -eq "other") { $cat = "macro" } }
    if ($t -match "buy|sell|long|short|目标|target|做多|做空") { $score += 1; $kwlist += "交易信号" }
    
    if ($score -ge 5) { $sig = "高" } elseif ($score -ge 3) { $sig = "中" }
    return @{ score = $score; category = $cat; signal = $sig; keywords = $kwlist }
}

# ── Interpretation ─────────────────────────────────────────────────
function Get-Interpretation($results) {
    $catScores = @{}
    $highCount = 0
    $sources = @{}
    
    foreach ($r in $results) {
        $cat = $r.category
        if (-not $catScores.ContainsKey($cat)) { $catScores[$cat] = 0 }
        $catScores[$cat] += $r.score
        if ($r.signal -eq "高") { $highCount++ }
        
        $src = "other"
        if ($r.url -match "bloomberg|reuters") { $src = "Bloomberg/Reuters" }
        elseif ($r.url -match "foxnews") { $src = "Fox News" }
        elseif ($r.url -match "wsj|ft\.com|nytimes|economist") { $src = "权威媒体" }
        elseif ($r.url -match "x\.com|twitter") { $src = "X/Twitter" }
        $sources[$src] = $true
    }
    
    $implications = @()
    $macro = if ($catScores.ContainsKey("macro")) { $catScores["macro"] } else { 0 }
    if ($macro -ge 4) {
        $implications += "地缘/宏观是当前市场主线，关注美伊谈判进展和油价走势"
    }
    if ($catScores.ContainsKey("crypto") -and $catScores["crypto"] -ge 3) {
        $implications += "BTC/加密市场情绪受Trump言论影响较大，注意风险"
    }
    if ($catScores.ContainsKey("commodity") -and $catScores["commodity"] -ge 3) {
        $implications += "能源/黄金等大宗商品受到关注，通胀预期可能升温"
    }
    if ($catScores.ContainsKey("equity") -and $catScores["equity"] -ge 3) {
        $implications += "美股市场情绪偏强，关注持续性"
    }
    if ($implications.Count -eq 0) {
        $implications += "当前无强烈单一方向信号，建议观望等待明确催化剂"
    }
    
    $srcList = $sources.Keys -join "、"
    $implications += "（来源：$srcList，$highCount 条高信号）"
    
    return ($implications -join " | ")
}

# ── Main ─────────────────────────────────────────────────────────
Write-Host "Trump Sentiment Analysis | $(Get-Date -Format 'HH:mm:ss')"

if ($File) {
    if (Test-Path $File) {
        $Data = Get-Content $File -Raw
        Write-Host "[File] Loaded data from $File"
    } else {
        Write-Host "[Error] File not found: $File"
        exit 1
    }
}

if ($Test) {
    $testFile = "$env:USERPROFILE\.openclaw\workspace\skills\trump-sentiment\test_data.json"
    if (Test-Path $testFile) {
        $Data = Get-Content $testFile -Raw
        Write-Host "[Test] Loaded test data"
    } else {
        Write-Host "[Test] No test file found"
        exit 0
    }
}

if (-not $Data -or $Data.Length -lt 10) {
    Write-Host "[Error] No data. Usage: -Data '<JSON array>'"
    exit 1
}

try {
    $allResults = $Data | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "[Error] JSON parse failed: $_"
    exit 1
}

Write-Host "Total items: $($allResults.Count)"

$seen = @{}
$noteworthy = @()
foreach ($r in $allResults) {
    $title = if ($r.title) { $r.title } else { "" }
    $desc = if ($r.snippet) { $r.snippet } elseif ($r.description) { $r.description } else { "" }
    $url = if ($r.url) { $r.url } else { "" }
    if ($title.Length -lt 5) { continue }
    
    $s = Score-Result $title $desc $url
    if ($s.score -ge 3 -and -not $seen.ContainsKey($url)) {
        $seen[$url] = $true
        $noteworthy += @{
            category = $s.category
            time = if ($r.time) { $r.time } else { "" }
            title = $title.Substring(0, [Math]::Min(200, $title.Length))
            snippet = $desc.Substring(0, [Math]::Min(200, $desc.Length))
            url = $url
            score = $s.score
            signal = $s.signal
            keywords = $s.keywords
        }
    }
}

$noteworthy = $noteworthy | Sort-Object score -Descending | Select-Object -First 15
$interpretation = Get-Interpretation $noteworthy

$result = @{
    checked = (Get-Date).ToUniversalTime().ToString("o")
    total_results = $allResults.Count
    noteworthy = @($noteworthy)
    count = $noteworthy.Count
    interpretation = $interpretation
}

Write-Host "Noteworthy: $($noteworthy.Count) | Interpretation: $interpretation"

if (-not $Test) {
    $OUTPUT_FILE = "$env:USERPROFILE\.openclaw\workspace\skills\trump-sentiment\analysis_output.json"
    $result | ConvertTo-Json -Depth 8 | Out-File $OUTPUT_FILE -Encoding UTF8 -Force
    Write-Host "Saved: $OUTPUT_FILE"
}

return $result
