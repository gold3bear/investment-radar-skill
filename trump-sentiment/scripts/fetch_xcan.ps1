[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "SilentlyContinue"

try {
    $r = Invoke-WebRequest -Uri "https://xcancel.com/KobeissiLetter" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -UseBasicParsing -TimeoutSec 20
    $r.Content | Out-File "$env:TEMP\kobeissi.html" -Encoding UTF8
    Write-Host "Kob: OK"
} catch { Write-Host "Kob: FAIL" $_.Exception.Message }

try {
    $r2 = Invoke-WebRequest -Uri "https://xcancel.com/WatcherGuru" -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 20
    $r2.Content | Out-File "$env:TEMP\watcher.html" -Encoding UTF8
    Write-Host "WG: OK"
} catch { Write-Host "WG: FAIL" $_.Exception.Message }

try {
    $r3 = Invoke-WebRequest -Uri "https://xcancel.com/search?q=Trump%20Iran%20ceasefire" -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 20
    $r3.Content | Out-File "$env:TEMP\xcancel2.html" -Encoding UTF8
    Write-Host "XCan2: OK"
} catch { Write-Host "XCan2: FAIL" $_.Exception.Message }
