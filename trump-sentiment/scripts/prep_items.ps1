$json = Get-Content "C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\analysis_input_0505_1050.json" -Raw | ConvertFrom-Json
$items = $json.items | ConvertTo-Json -Depth 20 -Compress
$items | Out-File -FilePath "C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\items_0505.json"
Write-Host "Items written: $($items.Length) chars"
