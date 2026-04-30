$data = Get-Content 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\items_only.json' -Raw | ConvertFrom-Json
$xItems = $data | Where-Object { $_.source -like '*x.com*' -or $_.source -like '*Twitter*' }
Write-Host "X items count: $($xItems.Count)"
$xItems | Select-Object title, source | ConvertTo-Json -Depth 3
