$html = Get-Content "$env:TEMP\kobeissi.html" -Raw
# Extract tweet dates
$dates = [regex]::Matches($html, 'tweet-date[^>]*>[^<]*<a[^>]*>([^<]+)</a>')
foreach ($d in $dates) {
    Write-Host "DATE:" $d.Groups[1].Value
}
Write-Host "---"
# Extract tweet content snippets
$contents = [regex]::Matches($html, 'class="tweet-content media-body" dir="auto">([^<]+)')
foreach ($c in $contents) {
    $text = $c.Groups[1].Value -replace '<[^>]+>', '' -replace '\s+', ' '
    if ($text.Length -gt 5) {
        Write-Host "TEXT:" $text.Substring(0, [Math]::Min(200, $text.Length))
    }
}
