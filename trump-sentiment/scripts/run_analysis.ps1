$d = Get-Content 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\data\websearch_results_20260331.json' -Raw
& 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\analyze.ps1' -Data $d
