# US Formulary Lens — Architecture and Design Decisions

> This file is append-only. Add new entries at the bottom with a date and phase tag.

---

## [Phase 0] 2026-11-11 — Star Schema Design

**Decision:** Use a star schema (not 3NF) for the analytical facts.  
**Rationale:** The dashboard runs analytical queries (GROUP BY state, drug, tier, year) that
benefit from wide flat joins. A star schema halves join depth vs. snowflake for these access
patterns. Surrogate integer PKs keep FK joins fast.

**Decision:** Separate fact tables by grain (formulary, spend, prescriber-drug, enrollment, LOE).  
**Rationale:** Mixing grains in one fact table causes fan-out errors in aggregations.
CMS explicitly warns that beneficiary counts from different files are not additive.

---

## [Phase 0] 2026-11-11 — Drug Join Strategy

**Decision:** Join formulary NDCs to prescriber/spend tables via normalized drug name, not NDC.  
**Rationale:** The prescriber and spending files do not carry NDCs. The only linkage available
is drug name. We normalize (UPPER, TRIM, strip punctuation) and report the match rate. Where
name matching fails we leave `drug_id` NULL and flag in `etl_audit`.

---

## [Phase 0] 2026-11-11 — Suppression Handling

**Decision:** Store suppressed GE65 values as NULL (never 0 or any imputed value).  
**Rationale:** CMS suppresses cells with ≤10 beneficiaries to protect privacy.  
Using 0 would bias all aggregate statistics downward. Flags (`ge65_sprsn_flag`,
`ge65_bene_sprsn_flag`) are retained as separate columns so downstream queries can
filter or count suppressed rows explicitly.

---

## [Phase 0] 2026-11-11 — Beneficiary Counting Caveat

**Decision:** Never report `SUM(tot_benes)` from fact_prescriber_drug as "unique beneficiaries".  
**Rationale:** The same Medicare beneficiary appears in many (prescriber, drug) rows. The
CMS data documentation explicitly states these are not additive. Enrollment CPSC data gives
~57M plan-county cell sums (also not unique individuals). The resume claim of "127M+ beneficiaries"
is not supportable from available data; we will report actual SUM(tot_benes) with the caveat,
and note that this overcounts individuals significantly.

---

## [Phase 0] 2026-11-11 — Pricing Table Exclusion

**Decision:** Inventory SPUF Pricing files but do not load into the database.  
**Rationale:** The Pricing table has ~54M rows. With Docker memory capped at ~2.8 GB,
loading it alongside the other fact tables would cause OOM. The pricing analysis module
uses the Drug Spending file (annual averages) instead, which is sufficient for the
cost-trend module.

---

## [Phase 0] 2026-11-11 — ETL Audit Table

**Decision:** Log every ETL run to `etl_audit` with row counts, null rates, duplicate key
counts, unmatched join counts, file checksum, and Git SHA of ETL code.  
**Rationale:** Provides reproducibility evidence for resume/portfolio; makes
data-quality issues traceable; supports Phase 5 pytest checks.

---

## [Phase 0] 2026-11-11 — Chunked Ingestion

**Decision:** Default chunk size = 250,000 rows for CSV reads; write intermediate Parquet.  
**Rationale:** The prescriber-drug file has ~28M rows. Reading in full would exhaust
available RAM. Parquet staging allows re-loading to Postgres without re-downloading.

---

## [Phase 0] 2026-11-11 — Part D Geography vs. Provider/Drug Reconciliation

**Decision:** Document and surface in the dashboard that Geography/Drug totals will NOT
match Provider/Drug totals.  
**Rationale:** CMS uses a broader Part D PDE population for the Geography file.
Both are correct within their own scope; they measure different populations. We label
each module's data source explicitly.
