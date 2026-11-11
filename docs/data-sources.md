# US Formulary Lens — Data Sources

> **CMS downloads require a US VPN** (data.cms.gov returns 403 from India).  
> Run the commands below **after connecting to a US VPN**.  
> The developer/AI assistant cannot fetch these; you must download them.

---

## 1. SPUF — Prescription Drug Plan Formulary, Pharmacy Network & Pricing

| Attribute | Value |
|-----------|-------|
| Full name | Quarterly Prescription Drug Plan Formulary, Pharmacy Network, and Pricing Information |
| Publisher | CMS |
| URL | <https://data.cms.gov/medicare-part-d/prescription-drug-plan-formulary-pharmacy-network-and-pricing-information> |
| Format | ZIP (may contain nested quarterly ZIPs); pipe-delimited (`\|`) inside |
| Expected size | ~2 GB compressed |
| Latest quarter | Use the **most recent** quarter available at download time |
| Target directory | `datasets\spuf\` |
| Expected filename | e.g. `PDP_Formulary_2024_Q3.zip` |

**Files needed inside the ZIP:**

| File pattern | Purpose | Load? |
|---|---|---|
| `*BasicDrugs*` | NDC, tier, PA, ST, QL per plan | ✅ Yes |
| `*PlanInformation*` | Contract, plan, insurer, service area | ✅ Yes |
| `*GeographicLocator*` | Plan ↔ state/county mapping | ✅ Yes |
| `*Pricing*` | Unit pricing (54M+ rows) | ❌ Inventory only |
| `*PharmacyNetwork*` | Pharmacy participation | ❌ Inventory only |

**How to download:**
```powershell
# After connecting US VPN
New-Item -ItemType Directory -Force -Path ".\datasets\spuf"
# Navigate to the URL above, click the latest quarter ZIP, save to .\datasets\spuf\
```

---

## 2. Medicare Part D Prescribers by Provider and Drug, 2024

| Attribute | Value |
|-----------|-------|
| Full name | Medicare Part D Prescribers by Provider and Drug |
| Publisher | CMS |
| Topic | Medicare Part D Prescribers |
| Dataset ID | `9552739e-3d05-4c1b-8eff-ecabf391e2e5` |
| Version ID (2024) | `d5aa71a8-dcc0-4570-8bcf-bd39deac69fe` |
| Rows (CMS reported) | 28,023,892 |
| Columns | 22 |
| Format | CSV (download) or JSON API |
| API endpoint | `https://data.cms.gov/data-api/v1/dataset/9552739e-3d05-4c1b-8eff-ecabf391e2e5/data` |
| Target directory | `datasets\prescriber_drug\` |
| Expected filename | `MUP_DPR_RY24_P04_V10_DY22_NPI.csv` (name varies) |

**How to download (run with VPN):**
```powershell
New-Item -ItemType Directory -Force -Path ".\datasets\prescriber_drug"
# Option A: Download CSV from CMS website directly
# Option B: Use the ETL script (Phase 1):
#   python etl\cms_api_extractor.py --full --out datasets\prescriber_drug\prescriber_drug_2024.csv
```

> **Important data-quality notes:**
> - All numeric fields arrive as **strings**; cast on ingest.
> - `GE65_Sprsn_Flag` = `"#"` → GE65 numeric fields suppressed (store as NULL, not 0).
> - `GE65_Bene_Sprsn_Flag` = `"*"` → beneficiary count suppressed.
> - Records with ≤10 claims are excluded by CMS; totals will be below program totals.
> - Rows are **aggregated prescriber-drug records**, NOT raw claims.

---

## 3. Medicare Part D Spending by Drug (Multi-Year)

| Attribute | Value |
|-----------|-------|
| Full name | Medicare Part D Spending by Drug |
| Publisher | CMS |
| Topic | Medicare Part D Prescribers |
| URL | <https://data.cms.gov/medicare-part-d/medicare-part-d-spending-by-drug> |
| Format | CSV |
| Target directory | `datasets\spending_by_drug\` |
| Coverage | Multiple annual files (download all available years for trend analysis) |

**How to download (run with VPN):**
```powershell
New-Item -ItemType Directory -Force -Path ".\datasets\spending_by_drug"
# Download each year's CSV from the URL above
```

---

## 4. Medicare Part D Prescribers by Geography and Drug

| Attribute | Value |
|-----------|-------|
| Full name | Medicare Part D Prescribers by Geography and Drug |
| Publisher | CMS |
| Topic | Medicare Part D Prescribers |
| URL | <https://data.cms.gov/medicare-part-d/medicare-part-d-prescribers-by-geography-and-drug> |
| Format | CSV |
| Target directory | `datasets\geo_drug\` |

> **Reconciliation caveat:** This file uses a broader Part D PDE population than the
> provider/drug detail file. Totals will NOT reconcile between these two sources.
> This is documented and expected; we surface this in the dashboard.

```powershell
New-Item -ItemType Directory -Force -Path ".\datasets\geo_drug"
```

---

## 5. Monthly Enrollment by Contract/Plan/State/County (CPSC)

| Attribute | Value |
|-----------|-------|
| Full name | Monthly Enrollment by Contract/Plan/State/County |
| Publisher | CMS |
| Section | Medicare Advantage and Part D Contract and Enrollment Data |
| URL | <https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-advantagepart-d-contract-and-enrollment-data/enrollment-by-contract> |
| Format | ZIP → CSV |
| Target directory | `datasets\cpsc\` |
| Use | Latest month available |

> **Coverage caveat:** Small enrollment cells are masked with `"*"`.  
> These are **plan-county aggregate counts**, not unique beneficiaries.

```powershell
New-Item -ItemType Directory -Force -Path ".\datasets\cpsc"
# Also download the companion Contract Info file from the same page
```

---

## 6. FDA Orange Book

| Attribute | Value |
|-----------|-------|
| Full name | FDA Orange Book Data Files |
| Publisher | FDA |
| URL | <https://www.fda.gov/drugs/drug-approvals-and-databases/orange-book-data-files> |
| Files needed | `products.txt`, `patent.txt`, `exclusivity.txt` |
| Format | Pipe-delimited (`~`) |
| Target directory | `datasets\orange_book\` |
| VPN needed? | **No** — FDA site accessible globally |

```powershell
New-Item -ItemType Directory -Force -Path ".\datasets\orange_book"
# Download the ZIP from the URL above; extract the three files
Invoke-WebRequest -Uri "https://www.fda.gov/media/76860/download" `
  -OutFile ".\datasets\orange_book\orange_book_data_files.zip"
Expand-Archive ".\datasets\orange_book\orange_book_data_files.zip" `
  -DestinationPath ".\datasets\orange_book\" -Force
```

> Note: FDA URL may change; verify on the page above before running.

---

## 7. Optional — RxNorm / NDC Mappings

| Attribute | Value |
|-----------|-------|
| Source | NLM RxNorm (Full Release) |
| URL | <https://www.nlm.nih.gov/research/umls/rxnorm/docs/rxnormfiles.shtml> |
| VPN needed? | No (requires free UMLS account) |
| Target directory | `datasets\rxnorm\` |
| Use | NDC-to-RxCUI mapping for joining formulary NDCs to drug spend tables |

---

## Out of Scope

- ACA Marketplace Benefits and Cost Sharing PUF (healthcare.gov) — excluded by design.
