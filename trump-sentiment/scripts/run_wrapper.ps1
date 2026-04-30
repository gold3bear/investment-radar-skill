$d = Get-Content 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\analysis_input.json' -Raw
& 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\analyze.ps1' -Data $d
