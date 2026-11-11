
# Profile key fields in all source files using PowerShell + .NET StreamReader
# Collects: distinct values for key columns, null/blank rates, sample values

Add-Type -AssemblyName System.Collections

function Profile-PipeFile {
    param([string]$Path, [string]$Label, [string[]]$KeyCols, [int]$SampleRows = 5)
    Write-Host "`n$('='*70)"
    Write-Host "FILE: $Label"
    Write-Host "PATH: $Path"
    if (-not (Test-Path $Path)) { Write-Host "  *** FILE NOT FOUND ***"; return }

    $reader = [System.IO.StreamReader]::new($Path)
    $header = $reader.ReadLine()
    $cols = $header -split '\|'
    Write-Host "COLUMNS ($($cols.Count)): $($cols -join ' | ')"

    # Build column index map
    $colIdx = @{}
    for ($i = 0; $i -lt $cols.Count; $i++) { $colIdx[$cols[$i].Trim()] = $i }

    $rowCount = 0
    $nullCounts = @{}
    $distinctSets = @{}
    foreach ($k in $KeyCols) {
        $nullCounts[$k] = 0
        if ($colIdx.ContainsKey($k)) { $distinctSets[$k] = [System.Collections.Generic.HashSet[string]]::new() }
    }
    $samples = [System.Collections.Generic.List[string]]::new()

    while ($null -ne ($line = $reader.ReadLine())) {
        $rowCount++
        $fields = $line -split '\|'
        if ($rowCount -le $SampleRows) { $samples.Add($line) }
        foreach ($k in $KeyCols) {
            if (-not $colIdx.ContainsKey($k)) { continue }
            $v = if ($colIdx[$k] -lt $fields.Count) { $fields[$colIdx[$k]].Trim() } else { "" }
            if ($v -eq "" -or $v -eq $null) { $nullCounts[$k]++ }
            if ($distinctSets.ContainsKey($k) -and $distinctSets[$k].Count -lt 100000) {
                [void]$distinctSets[$k].Add($v)
            }
        }
    }
    $reader.Close()

    Write-Host "TOTAL DATA ROWS: $($rowCount.ToString('N0'))"
    foreach ($k in $KeyCols) {
        if (-not $colIdx.ContainsKey($k)) { Write-Host "  $k : COLUMN NOT FOUND"; continue }
        $nullPct = if ($rowCount -gt 0) { [math]::Round($nullCounts[$k] * 100.0 / $rowCount, 2) } else { 0 }
        $distCount = if ($distinctSets.ContainsKey($k)) { $distinctSets[$k].Count } else { "N/A" }
        Write-Host ("  {0,-30} null%={1,6}  distinct={2}" -f $k, "$nullPct%", $distCount)
    }
    Write-Host "SAMPLE ROWS:"
    $samples | ForEach-Object { Write-Host "  $_" }
}

function Profile-CsvFile {
    param([string]$Path, [string]$Label, [string[]]$KeyCols, [int]$SampleRows = 3)
    Write-Host "`n$('='*70)"
    Write-Host "FILE: $Label"
    Write-Host "PATH: $Path"
    if (-not (Test-Path $Path)) { Write-Host "  *** FILE NOT FOUND ***"; return }

    $reader = [System.IO.StreamReader]::new($Path)
    $header = $reader.ReadLine()
    # Handle quoted CSV header
    $cols = $header -replace '"','' -split ','
    Write-Host "COLUMNS ($($cols.Count)): $($cols -join ' | ')"

    $colIdx = @{}
    for ($i = 0; $i -lt $cols.Count; $i++) { $colIdx[$cols[$i].Trim()] = $i }

    $rowCount = 0
    $nullCounts = @{}
    $distinctSets = @{}
    foreach ($k in $KeyCols) {
        $nullCounts[$k] = 0
        if ($colIdx.ContainsKey($k)) { $distinctSets[$k] = [System.Collections.Generic.HashSet[string]]::new() }
    }
    $samples = [System.Collections.Generic.List[string]]::new()

    while ($null -ne ($line = $reader.ReadLine())) {
        $rowCount++
        # Simple CSV split (handles most cases; not RFC 4180 fully)
        $fields = $line -replace '"','' -split ','
        if ($rowCount -le $SampleRows) { $samples.Add($line) }
        foreach ($k in $KeyCols) {
            if (-not $colIdx.ContainsKey($k)) { continue }
            $v = if ($colIdx[$k] -lt $fields.Count) { $fields[$colIdx[$k]].Trim() } else { "" }
            if ($v -eq "" -or $v -eq "*") { $nullCounts[$k]++ }
            if ($distinctSets.ContainsKey($k) -and $distinctSets[$k].Count -lt 50000) {
                [void]$distinctSets[$k].Add($v)
            }
        }
    }
    $reader.Close()

    Write-Host "TOTAL DATA ROWS: $($rowCount.ToString('N0'))"
    foreach ($k in $KeyCols) {
        if (-not $colIdx.ContainsKey($k)) { Write-Host "  $k : COLUMN NOT FOUND"; continue }
        $nullPct = if ($rowCount -gt 0) { [math]::Round($nullCounts[$k] * 100.0 / $rowCount, 2) } else { 0 }
        $distCount = if ($distinctSets.ContainsKey($k)) { $distinctSets[$k].Count } else { "N/A" }
        Write-Host ("  {0,-35} blank/masked%={1,6}  distinct={2}" -f $k, "$nullPct%", $distCount)
    }
    Write-Host "SAMPLE ROWS:"
    $samples | Select-Object -First $SampleRows | ForEach-Object { Write-Host "  $_" }
}

# ---- SPUF BasicDrugs ----
Profile-PipeFile `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf\basic drugs formulary file PPUF_2026Q3\basic drugs formulary file  PPUF_2026Q3.txt" `
  "SPUF BasicDrugs" `
  @('FORMULARY_ID','RXCUI','NDC','TIER_LEVEL_VALUE','PRIOR_AUTHORIZATION_YN','STEP_THERAPY_YN','QUANTITY_LIMIT_YN')

# ---- SPUF PlanInfo ----
Profile-PipeFile `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf\plan information PPUF_2026Q3\plan information  PPUF_2026Q3.txt" `
  "SPUF PlanInformation" `
  @('CONTRACT_ID','PLAN_ID','STATE','CONTRACT_NAME','FORMULARY_ID')

# ---- SPUF GeoLocator ----
Profile-PipeFile `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf\geographic locator file PPUF_2026Q3\geographic locator file PPUF_2026Q3.txt" `
  "SPUF GeoLocator" `
  @('COUNTY_CODE','STATENAME','COUNTY')

# ---- Geo Drug ----
Profile-CsvFile `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\Medicare Part D Prescribers - by Geography and Drug\Medicare Part D Prescribers - by Geography and Drug\2024\MUP_DPR_RY26_P04_V10_DY24_Geo.csv" `
  "GeoDrug 2024" `
  @('Prscrbr_Geo_Lvl','Prscrbr_Geo_Cd','Prscrbr_Geo_Desc','Brnd_Name','Gnrc_Name','Tot_Clms','Tot_Drug_Cst','Tot_Benes','GE65_Sprsn_Flag','GE65_Bene_Sprsn_Flag')

# ---- CPSC Enrollment ----
Profile-CsvFile `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\cpsc_enrollment_2026_10\CPSC_Enrollment_2026_10\CPSC_Enrollment_Info_2026_10.csv" `
  "CPSC Enrollment Oct 2026" `
  @('Contract Number','Plan ID','State','County','Enrollment')

# ---- CPSC Contract Info ----
Profile-CsvFile `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\cpsc_enrollment_2026_10\CPSC_Enrollment_2026_10\CPSC_Contract_Info_2026_10.csv" `
  "CPSC ContractInfo Oct 2026" `
  @('Contract ID','Plan ID','Organization Type','Offers Part D','Parent Organization')

Write-Host "`n$('='*70)"
Write-Host "PROFILE COMPLETE"
