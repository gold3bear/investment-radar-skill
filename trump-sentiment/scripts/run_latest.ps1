$Data = Get-Content 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\data_latest.json' -Raw
& 'C:\Users\gold3\.openclaw\workspace\skills\trump-sentiment\scripts\analyze.ps1' -Data $Data
