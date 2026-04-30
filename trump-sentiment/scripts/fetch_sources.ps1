[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "SilentlyContinue"
$out = @()

# Google News Live - Trump Iran
try {
    $r1 = Invoke-WebRequest -Uri "https://news.google.com/rss/search?q=Trump+Iran+ceasefire+when:1h&hl=en-US&gl=US&ceid=US:en" -UseBasicParsing -TimeoutSec 15
    $r1.Content | Out-File -FilePath "$env:TEMP\gn1.xml" -Encoding UTF8
    $out += "GN_TRUMP_IRAN: OK"
} catch { $out += "GN_TRUMP_IRAN: FAIL " + $_.Exception.Message }

# Google News Live - Iran war
try {
    $r2 = Invoke-WebRequest -Uri "https://news.google.com/rss/search?q=Iran+war+when:1h&hl=en-US&gl=US&ceid=US:en" -UseBasicParsing -TimeoutSec 15
    $r2.Content | Out-File -FilePath "$env:TEMP\gn2.xml" -Encoding UTF8
    $out += "GN_IRAN_WAR: OK"
} catch { $out += "GN_IRAN_WAR: FAIL " + $_.Exception.Message }

# Truth Social
try {
    $r3 = Invoke-WebRequest -Uri "https://truthsocial.com/@realDonaldTrump" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -UseBasicParsing -TimeoutSec 15
    $r3.Content | Out-File -FilePath "$env:TEMP\truth.html" -Encoding UTF8
    $out += "TRUTH: OK"
} catch { $out += "TRUTH: FAIL " + $_.Exception.Message }

# XCancel search
try {
    $r4 = Invoke-WebRequest -Uri "https://xcancel.com/search?q=Trump%20Iran%20deal" -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 15
    $r4.Content | Out-File -FilePath "$env:TEMP\xcancel.html" -Encoding UTF8
    $out += "XCANCEL: OK"
} catch { $out += "XCANCEL: FAIL " + $_.Exception.Message }

# XCancel Kobeissi
try {
    $r5 = Invoke-WebRequest -Uri "https://xcancel.com/KobeissiLetter" -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 15
    $r5.Content | Out-File -FilePath "$env:TEMP\kobeissi.html" -Encoding UTF8
    $out += "XCANCEL_KOBEISSI: OK"
} catch { $out += "XCANCEL_KOBEISSI: FAIL " + $_.Exception.Message }

$out
