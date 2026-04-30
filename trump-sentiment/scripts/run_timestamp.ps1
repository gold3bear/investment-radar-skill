$data = Get-Content 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\analysis_input.json' -Raw | ConvertFrom-Json
$json = $data.data | ConvertTo-Json -Compress -Depth 10
$script = 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\analyze.ps1'
& $script -Data $json
