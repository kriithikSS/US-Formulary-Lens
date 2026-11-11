# US Formulary Lens (Access D360)

**Medicare Part D Formulary, Pricing and Utilization Analytics Platform**

> A portfolio analytics project built on real CMS and FDA public datasets.
> Every statistic in this README is derived from the actual loaded data —
> no numbers are fabricated or tuned to match a resume claim.

---

## Architecture Overview

```
CMS / FDA Public Data
        │
        ▼
   datasets/          ← raw downloads (git-ignored)
        │
   etl/               ← Python ETL scripts
        │
   parquet/           ← intermediate staging (git-ignored)
        │
   PostgreSQL 16      ← star schema (Docker)
   (Docker)                │
        │             sql/schema.sql
        ▼
   dashboard/         ← Streamlit + Plotly (6 modules)
        │
   ml/                ← scikit-learn / XGBoost / SHAP
```

---

## Modules

| # | Name | Key Data Sources |
|---|------|-----------------|
| 1 | Formulary Coverage Explorer | SPUF BasicDrugs, PlanInfo |
| 2 | Drug Spend & Pricing Trends | CMS Drug Spending (multi-year) |
| 3 | Insurer Coverage & Enrollment Share | SPUF + CPSC enrollment |
| 4 | Geographic Utilization Map | Geo/Drug file (state-level) |
| 5 | Exclusivity & LOE Timeline | FDA Orange Book |
| 6 | ML — Tier/PA Prediction, Spend Forecast, Drug Clustering | All facts |

---

## Quick Start

### 1. Prerequisites
- Docker Desktop (Windows), Python 3.11+, miniconda
- **US VPN** for CMS data downloads (data.cms.gov blocks non-US IPs)

### 2. Clone and configure

```powershell
git clone <repo-url>
cd US-Formulary-Lens
Copy-Item .env.example .env
# Edit .env — change passwords before first use
```

### 3. Start the database

```powershell
docker compose up -d db
# Wait ~15 seconds for Postgres to initialise
docker compose logs db --tail 20
```

### 4. Install Python dependencies

```powershell
conda create -n flens python=3.11 -y
conda activate flens
pip install -r requirements.txt
```

### 5. Download data (US VPN required for CMS files)

See [docs/data-sources.md](docs/data-sources.md) for exact URLs and filenames.
Put all raw files in `datasets/` subdirectories as specified there.

FDA Orange Book can be downloaded without a VPN — see the data-sources doc.

### 6. Run ETL

```powershell
# Schema creation
python etl/schema_setup.py

# SPUF formulary
python etl/load_spuf.py

# Prescriber/Drug (CSV path — after VPN download)
python etl/load_prescriber_drug.py --input datasets/prescriber_drug/prescriber_drug_2024.csv

# Drug spending, geo/drug, CPSC, Orange Book
python etl/load_spending.py
python etl/load_geo_drug.py
python etl/load_cpsc.py
python etl/load_orange_book.py
```

### 7. Launch dashboard

```powershell
streamlit run dashboard/app.py
```

---

## Data Limitations (Honest Accounting)

| Claim | Status | Actual |
|-------|--------|--------|
| "26.4M+ claims" | Verify Phase 1 | `SUM(Tot_Clms)` from prescriber/drug file — TBD |
| "\$3.52B in drug cost" | Verify Phase 1 | `SUM(Tot_Drug_Cst)` — TBD |
| "1,257+ drugs" | Verify Phase 1 | Distinct generic names, brand names, NDCs — TBD |
| "50 states" | Expected | Verify distinct states in geo/drug and prescriber files |
| "617 drug LOE dates" | Verify Phase 1 | Distinct drugs with an Orange Book exclusivity date — TBD |
| "127M+ beneficiaries" | Likely not supportable | `SUM(Tot_Benes)` overcounts; CPSC gives ~57M enrollment cells — TBD |

> This table is updated after Phase 1 ETL with real query results.

---

## Project Structure

```
US-Formulary-Lens/
├── datasets/           # raw downloads (git-ignored)
│   ├── spuf/
│   ├── prescriber_drug/
│   ├── spending_by_drug/
│   ├── geo_drug/
│   ├── cpsc/
│   └── orange_book/
├── docs/
│   ├── data-dictionary.md
│   ├── data-sources.md
│   ├── data-provenance.md  # created Phase 1
│   └── decisions.md
├── etl/                # Python ETL scripts
├── sql/
│   ├── init/           # docker-entrypoint init SQL
│   └── schema.sql      # star schema DDL
├── notebooks/          # EDA (Phase 2)
├── ml/                 # ML pipelines (Phase 3)
├── dashboard/          # Streamlit app (Phase 4)
├── models/             # saved ML models (large files git-ignored)
├── tests/              # pytest (Phase 5)
├── parquet/            # staging (git-ignored)
├── docker-compose.yml
├── requirements.txt
├── .env.example
└── .gitignore
```

---

## Tech Stack

- **Data:** Python 3.11, pandas, polars, pyarrow/parquet
- **Database:** PostgreSQL 16 (Docker; AWS RDS-compatible schema)
- **ETL:** SQLAlchemy, psycopg3, tenacity (retries)
- **ML:** scikit-learn, XGBoost, SHAP, statsmodels
- **Dashboard:** Streamlit, Plotly, pydeck (choropleth maps)
- **Testing:** pytest, pytest-cov
- **Quality:** black, ruff

---

## Resume Claims Audit

> Full audit table with SQL queries and real figures: populated after Phase 1.

---

## Docs

- [Data Sources](docs/data-sources.md)
- [Data Dictionary](docs/data-dictionary.md)
- [Design Decisions](docs/decisions.md)
- [Data Provenance](docs/data-provenance.md) *(Phase 1)*
