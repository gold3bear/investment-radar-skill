[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "SilentlyContinue"

# Fetch AP article on US-Iran talks
try {
    $r = Invoke-WebRequest -Uri "https://apnews.com/article/us-iran-talks-pakistan-ceasefire-a0a8b5c0e8f4" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -UseBasicParsing -TimeoutSec 20
    $r.Content | Out-File "$env:TEMP\ap_iran.xml" -Encoding UTF8
    Write-Host "AP: OK"
} catch {
    Write-Host "AP: FAIL" $_.Exception.Message
}

# Fetch ZeroHedge XCancel
try {
    $r2 = Invoke-WebRequest -Uri "https://xcancel.com/zerohedge" -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 20
    $r2.Content | Out-File "$env:TEMP\zerohedge.html" -Encoding UTF8
    Write-Host "ZH: OK"
} catch {
    Write-Host "ZH: FAIL" $_.Exception.Message
}
