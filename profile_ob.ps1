
Add-Type -AssemblyName System.Collections

function Count-TildeFile {
    param([string]$Path, [string]$Label, [string[]]$KeyCols)
    Write-Host ""
    Write-Host "FILE: $Label"
    $reader = [System.IO.StreamReader]::new($Path)
    $header = $reader.ReadLine()
    $cols = $header -split '~'
    $ncols = $cols.Count
    Write-Host "COLUMNS ($ncols): $($cols -join ' | ')"
    $colIdx = @{}
    for ($i = 0; $i -lt $cols.Count; $i++) { $colIdx[$cols[$i].Trim()] = $i }
    $rowCount = 0
    $distinct = @{}
    foreach ($k in $KeyCols) {
        if ($colIdx.ContainsKey($k)) { $distinct[$k] = [System.Collections.Generic.HashSet[string]]::new() }
    }
    while ($null -ne ($line = $reader.ReadLine())) {
        $rowCount++
        $fields = $line -split '~'
        foreach ($k in $KeyCols) {
            if (-not $colIdx.ContainsKey($k)) { continue }
            $idx = $colIdx[$k]
            $v = if ($idx -lt $fields.Count) { $fields[$idx].Trim() } else { '' }
            if ($distinct.ContainsKey($k)) { [void]$distinct[$k].Add($v) }
        }
    }
    $reader.Close()
    Write-Host "ROWS: $rowCount"
    foreach ($k in $KeyCols) {
        if ($colIdx.ContainsKey($k)) {
            $cnt = $distinct[$k].Count
            Write-Host "  $k  distinct=$cnt"
        }
    }
}

Count-TildeFile `
    'C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\EOBZIP_2026_09\products.txt' `
    'OB Products' `
    @('Ingredient','Trade_Name','Appl_Type','Appl_No','Type')

Count-TildeFile `
    'C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\EOBZIP_2026_09\patent.txt' `
    'OB Patent' `
    @('Appl_Type','Appl_No','Patent_No','Patent_Expire_Date_Text')

Count-TildeFile `
    'C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\EOBZIP_2026_09\exclusivity.txt' `
    'OB Exclusivity' `
    @('Appl_Type','Appl_No','Exclusivity_Code','Exclusivity_Date')

Write-Host "Orange Book profiling done."
