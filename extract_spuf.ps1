
Add-Type -AssemblyName System.IO.Compression.FileSystem

$outerZip = 'C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\Quarterly Prescription Drug Plan Formulary, Pharmacy Network, and Pricing Information\Quarterly Prescription Drug Plan Formulary, Pharmacy Network, and Pricing Information\2026-Q3\SPUF_2026_20261007.zip'
$extractDir = 'C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\extracted\spuf'

# Files to fully extract (pipe-delimited CSVs inside these inner ZIPs)
$toExtract = @(
    'basic drugs formulary file  PPUF_2026Q3.zip',
    'plan information  PPUF_2026Q3.zip',
    'geographic locator file  PPUF_2026Q3.zip',
    'excluded drugs formulary file  PPUF_2026Q3.zip',
    'beneficiary cost file  PPUF_2026Q3.zip',
    'sample files PPUF_2026Q3.zip'
)

# Open outer ZIP
$outer = [System.IO.Compression.ZipFile]::OpenRead($outerZip)

foreach ($entry in $outer.Entries) {
    $innerName = $entry.FullName
    $innerZipPath = Join-Path $extractDir ($entry.Name -replace '[\\/:*?"<>|]', '_')

    if ($innerName -in $toExtract) {
        Write-Host "Extracting inner ZIP: $innerName  ($([math]::Round($entry.Length/1MB,1)) MB)"
        # Write inner ZIP to disk temporarily
        $tmpPath = Join-Path $env:TEMP ($entry.Name -replace '[\\/:*?"<>|]', '_')
        $stream = $entry.Open()
        $fs = [System.IO.File]::Create($tmpPath)
        $stream.CopyTo($fs)
        $fs.Close(); $stream.Close()

        # Extract inner ZIP
        $innerDest = Join-Path $extractDir ($entry.Name -replace '\.zip$','' -replace '[\\/:*?"<>|]','_' -replace '\s+',' ').Trim()
        New-Item -ItemType Directory -Force -Path $innerDest | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpPath, $innerDest)
        Remove-Item $tmpPath
        Write-Host "  -> $innerDest"
    } else {
        # Just report size for large files we do NOT extract
        Write-Host "SKIP (large/not needed): $innerName  ($([math]::Round($entry.Length/1MB,1)) MB compressed)"
    }
}

$outer.Dispose()
Write-Host "`nDone. Extracted files:"
Get-ChildItem -Recurse $extractDir | Where-Object { -not $_.PSIsContainer } | Select-Object FullName, Length | Format-Table -AutoSize
