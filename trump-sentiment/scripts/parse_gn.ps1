# Parse GN1 - Trump Iran ceasefire
[xml]$gn1 = Get-Content "$env:TEMP\gn1.xml" -Raw
Write-Host "=== GN Trump Iran Ceasefire (last 1h) ==="
$gn1.rss.channel.item | Select-Object -First 15 | ForEach-Object {
    $pub = $_.pubDate
    $title = $_.title -replace '<[^>]+>', ''
    Write-Host "[$pub] $title"
}

Write-Host ""
Write-Host "=== GN Iran War (last 1h) ==="
[xml]$gn2 = Get-Content "$env:TEMP\gn2.xml" -Raw
$gn2.rss.channel.item | Select-Object -First 10 | ForEach-Object {
    $pub = $_.pubDate
    $title = $_.title -replace '<[^>]+>', ''
    Write-Host "[$pub] $title"
}
