import zipfile, os, sys

zp = r'C:\Users\lenovo\Downloads\US-Formulary-Lens\datasets\Quarterly Prescription Drug Plan Formulary, Pharmacy Network, and Pricing Information\Quarterly Prescription Drug Plan Formulary, Pharmacy Network, and Pricing Information\2026-Q3\SPUF_2026_20261007.zip'

try:
    with zipfile.ZipFile(zp) as z:
        names = z.namelist()
    print(f'Total entries: {len(names)}')
    for n in names[:60]:
        info = z.getinfo(n)
        print(f'  {info.file_size:>14,}  {n}')
    if len(names) > 60:
        print(f'  ... and {len(names)-60} more entries')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
