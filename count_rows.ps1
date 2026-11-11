
# Count rows in all key files (excluding header line)
# Uses StreamReader for memory efficiency on large files

function Count-FileRows {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) { Write-Host "MISSING: $Label"; return }
    $count = 0
    $reader = [System.IO.StreamReader]::new($Path)
    $null = $reader.ReadLine()   # skip header
    while ($null -ne $reader.ReadLine()) { $count++ }
    $reader.Close()
    $sizeMB = [math]::Round((Get-Item $Path).Length / 1MB, 2)
    Write-Host ("{0,-55} rows={1,10:N0}  size={2,8} MB" -f $Label, $count, $sizeMB)
}

Write-Host "`n=== Row Counts (excluding header) ===`n"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf\basic drugs formulary file PPUF_2026Q3\basic drugs formulary file  PPUF_2026Q3.txt" `
  "SPUF BasicDrugs"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf\plan information PPUF_2026Q3\plan information  PPUF_2026Q3.txt" `
  "SPUF PlanInformation"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf\geographic locator file PPUF_2026Q3\geographic locator file PPUF_2026Q3.txt" `
  "SPUF GeoLocator"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf\excluded drugs formulary file PPUF_2026Q3\excluded drugs formulary file  PPUF_2026Q3.txt" `
  "SPUF ExcludedDrugs"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\Medicare Part D Prescribers - by Geography and Drug\Medicare Part D Prescribers - by Geography and Drug\2024\MUP_DPR_RY26_P04_V10_DY24_Geo.csv" `
  "GeoDrug"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\cpsc_enrollment_2026_10\CPSC_Enrollment_2026_10\CPSC_Enrollment_Info_2026_10.csv" `
  "CPSC Enrollment"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\cpsc_enrollment_2026_10\CPSC_Enrollment_2026_10\CPSC_Contract_Info_2026_10.csv" `
  "CPSC ContractInfo"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\EOBZIP_2026_09\products.txt" `
  "OrangeBook Products"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\EOBZIP_2026_09\patent.txt" `
  "OrangeBook Patent"

Count-FileRows `
  "C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\EOBZIP_2026_09\exclusivity.txt" `
  "OrangeBook Exclusivity"

Write-Host "`nDone."
