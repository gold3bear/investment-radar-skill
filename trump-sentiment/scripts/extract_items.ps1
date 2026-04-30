$d = Get-Content 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\data\forced_run_20260405_0309.json' -Raw | ConvertFrom-Json
$items = $d.items
$items | ConvertTo-Json -Depth 10 | Out-File 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\items_only.json' -Encoding UTF8
Write-Host "Exported $($items.Count) items"
