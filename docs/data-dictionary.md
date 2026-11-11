# US Formulary Lens — Data Dictionary

> **Grain and honesty rules:**  
> - "Claims" = `SUM(Tot_Clms)` over aggregated provider-drug records, NOT raw prescription events.  
> - "Beneficiaries" from the prescriber/drug file cannot be summed to unique individuals.  
> - "Enrollment" = plan-county aggregate cells from CPSC, NOT unique enrollees.  
> - Suppression: GE65 fields suppressed by CMS when ≤10 beneficiaries; stored as NULL.  
> All join logic and match rates are documented per module below.

---

## Dimension Tables

### `dim_drug`

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `drug_id` | SERIAL PK | — | Surrogate key |
| `ndc11` | CHAR(11) | SPUF BasicDrugs | Zero-padded 11-digit NDC; NULL if invalid |
| `ndc_valid` | BOOLEAN | derived | TRUE if 11 digits numeric |
| `brnd_name` | TEXT | Prescriber/Drug file | As received from CMS |
| `gnrc_name` | TEXT | Prescriber/Drug file | As received from CMS |
| `drug_name_normalized` | TEXT | derived | UPPER TRIM for joining |
| `rxcui` | TEXT | RxNorm (optional) | NULL if not mapped |
| `atc_code` | TEXT | optional | NULL until mapped |
| `created_at` | TIMESTAMPTZ | ETL | Load timestamp |

> **Join approach:** Formulary NDCs join to spending/prescriber tables via normalized drug name  
> (generic name match after uppercasing and stripping punctuation), NOT via NDC.  
> NDC is plan-formulary-specific and not present in the prescriber file.  
> Match rate is reported in `etl_audit`.

---

### `dim_plan`

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `plan_id` | SERIAL PK | — | Surrogate key |
| `contract_id` | VARCHAR(10) | SPUF PlanInfo | CMS contract identifier (e.g. S1234) |
| `plan_benefit_pkg_id` | SMALLINT | SPUF PlanInfo | PBP identifier |
| `contract_plan_key` | VARCHAR(15) | derived | `contract_id || '-' || plan_benefit_pkg_id`; unique |
| `plan_name` | TEXT | SPUF PlanInfo | |
| `organization_type` | TEXT | SPUF PlanInfo | PDP, MA-PD, etc. |
| `parent_org` | TEXT | SPUF PlanInfo | Insurer/sponsor name |
| `part_d_flag` | BOOLEAN | derived | TRUE for Part D plans |
| `service_area_state` | VARCHAR(2)[] | SPUF GeoLocator | Array of state abbreviations |

---

### `dim_geography`

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `geo_id` | SERIAL PK | — | Surrogate key |
| `state_abbr` | CHAR(2) | CPSC / GeoLocator | 50 states + DC + territories |
| `state_fips` | CHAR(2) | Prescriber/Drug | NULL for territories in some files |
| `state_name` | TEXT | lookup | Standard name |
| `county_name` | TEXT | CPSC | NULL for state-level aggregates |
| `county_fips` | CHAR(5) | CPSC | NULL for state-level aggregates |
| `geo_level` | VARCHAR(10) | derived | `'state'` or `'county'` |

---

### `dim_prescriber_specialty`

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `specialty_id` | SERIAL PK | — | |
| `prscrbr_type` | TEXT | Prescriber/Drug | As-received CMS taxonomy |
| `prscrbr_type_src` | VARCHAR(10) | Prescriber/Drug | `'S'` = specialty, `'T'` = type |

---

### `dim_period`

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `period_id` | SERIAL PK | — | |
| `year` | SMALLINT | derived | Calendar year |
| `quarter` | SMALLINT | derived | 1–4; NULL for annual files |
| `period_label` | VARCHAR(10) | derived | e.g. `'2024-Q3'`, `'2024'` |
| `source_file` | TEXT | ETL | Originating filename |

---

## Fact Tables

### `fact_formulary_coverage`

**Grain:** One row per (contract-plan, NDC, formulary period).

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `formulary_id` | BIGSERIAL PK | — | |
| `plan_id` | INT FK | dim_plan | |
| `drug_id` | INT FK | dim_drug | Matched on NDC |
| `period_id` | INT FK | dim_period | |
| `tier_level_value` | SMALLINT | SPUF BasicDrugs | 1–9; NULL if blank |
| `prior_auth_yn` | BOOLEAN | SPUF BasicDrugs | |
| `step_therapy_yn` | BOOLEAN | SPUF BasicDrugs | |
| `quantity_limit_yn` | BOOLEAN | SPUF BasicDrugs | |
| `quantity_limit_detail` | TEXT | SPUF BasicDrugs | Raw QL detail string |
| `formulary_status` | SMALLINT | SPUF BasicDrugs | CMS status code |

---

### `fact_drug_spend`

**Grain:** One row per (drug name, year).  
**Source:** Medicare Part D Spending by Drug.

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `spend_id` | BIGSERIAL PK | — | |
| `drug_id` | INT FK | dim_drug | Matched on normalized name |
| `period_id` | INT FK | dim_period | Annual |
| `tot_mftr_name` | TEXT | Spending file | Manufacturer |
| `tot_spndng` | NUMERIC(18,2) | Spending file | Total Part D spending |
| `tot_dsg_unts` | BIGINT | Spending file | Total dosage units |
| `tot_clms` | BIGINT | Spending file | Total claims |
| `tot_benes` | INT | Spending file | Total beneficiaries (not summable to unique) |
| `avg_spnd_per_clm` | NUMERIC(12,4) | Spending file | Avg cost per claim |
| `avg_spnd_per_dsg_unt_wghtd` | NUMERIC(12,6) | Spending file | Avg cost per dosage unit |
| `bene_suppression_flag` | BOOLEAN | derived | TRUE if beneficiaries suppressed |

---

### `fact_prescriber_drug`

**Grain:** One row per (NPI, drug name, year).  
**Source:** Medicare Part D Prescribers by Provider and Drug, 2024.

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `pd_id` | BIGSERIAL PK | — | |
| `npi` | CHAR(10) | Prescriber/Drug | National Provider Identifier |
| `prscrbr_last_org_name` | TEXT | Prescriber/Drug | |
| `prscrbr_first_name` | TEXT | Prescriber/Drug | NULL for org providers |
| `geo_id` | INT FK | dim_geography | Joined on state_abbr |
| `specialty_id` | INT FK | dim_prescriber_specialty | |
| `drug_id` | INT FK | dim_drug | Matched on brnd+gnrc name |
| `period_id` | INT FK | dim_period | 2024 annual |
| `tot_clms` | INT | Prescriber/Drug | Aggregated claim count (≥10 by CMS rule) |
| `tot_30day_fills` | NUMERIC(10,1) | Prescriber/Drug | |
| `tot_day_suply` | BIGINT | Prescriber/Drug | |
| `tot_drug_cst` | NUMERIC(14,2) | Prescriber/Drug | |
| `tot_benes` | INT | Prescriber/Drug | NOT summable to unique beneficiaries |
| `ge65_sprsn_flag` | CHAR(1) | Prescriber/Drug | `'#'` or NULL |
| `ge65_bene_sprsn_flag` | CHAR(1) | Prescriber/Drug | `'*'` or NULL |
| `ge65_tot_clms` | INT | Prescriber/Drug | NULL when suppressed |
| `ge65_tot_30day_fills` | NUMERIC(10,1) | Prescriber/Drug | NULL when suppressed |
| `ge65_tot_drug_cst` | NUMERIC(14,2) | Prescriber/Drug | NULL when suppressed |
| `ge65_tot_day_suply` | BIGINT | Prescriber/Drug | NULL when suppressed |
| `ge65_tot_benes` | INT | Prescriber/Drug | NULL when suppressed |

---

### `fact_geo_drug`

**Grain:** One row per (state, drug name, year).  
**Source:** Medicare Part D Prescribers by Geography and Drug.

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `geo_drug_id` | BIGSERIAL PK | — | |
| `geo_id` | INT FK | dim_geography | |
| `drug_id` | INT FK | dim_drug | Matched on normalized name |
| `period_id` | INT FK | dim_period | |
| `tot_prscrbrs` | INT | Geo/Drug file | Prescriber count |
| `tot_clms` | BIGINT | Geo/Drug file | |
| `tot_drug_cst` | NUMERIC(18,2) | Geo/Drug file | |
| `tot_benes` | INT | Geo/Drug file | NOT summable to unique |

> **Reconciliation note:** This table uses a broader CMS Part D PDE population.  
> `SUM(tot_clms)` will exceed `fact_prescriber_drug` totals. Documented intentionally.

---

### `fact_enrollment`

**Grain:** One row per (contract, plan, state, county, month).  
**Source:** CPSC monthly enrollment file.

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `enroll_id` | BIGSERIAL PK | — | |
| `plan_id` | INT FK | dim_plan | |
| `geo_id` | INT FK | dim_geography | County level |
| `period_id` | INT FK | dim_period | Month |
| `enrollment` | INT | CPSC | NULL when masked (`'*'`); aggregate cell count |
| `enrollment_masked` | BOOLEAN | derived | TRUE when original value was `'*'` |

> **Caveat:** These are **enrollment cell counts**, NOT unique beneficiaries.  
> The same person can appear in multiple plan-county cells.  
> Do not sum across rows to derive unique beneficiary counts.

---

### `fact_loe`

**Grain:** One row per (application number, patent/exclusivity code).  
**Source:** FDA Orange Book (patent.txt + exclusivity.txt).

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `loe_id` | SERIAL PK | — | |
| `drug_id` | INT FK | dim_drug | Matched on ingredient name (best-effort) |
| `appl_no` | VARCHAR(10) | Orange Book | NDA/ANDA number |
| `product_no` | VARCHAR(10) | Orange Book | |
| `ingredient` | TEXT | Orange Book | Active ingredient |
| `trade_name` | TEXT | Orange Book | Brand name |
| `applicant` | TEXT | Orange Book | Manufacturer |
| `strength` | TEXT | Orange Book | |
| `appl_type` | CHAR(1) | Orange Book | `N`=NDA, `A`=ANDA |
| `patent_no` | TEXT | patent.txt | NULL for exclusivity rows |
| `exclusivity_code` | TEXT | exclusivity.txt | e.g. `NCE`, `ODE`, `M` |
| `exclusivity_date` | DATE | Orange Book | Expiry date |
| `patent_expire_date` | DATE | patent.txt | NULL for exclusivity rows |
| `loe_type` | VARCHAR(15) | derived | `'patent'` or `'exclusivity'` |

---

## ETL Audit Table

### `etl_audit`

| Column | Type | Notes |
|--------|------|-------|
| `audit_id` | SERIAL PK | |
| `load_timestamp` | TIMESTAMPTZ | When load ran |
| `source_name` | TEXT | e.g. `'prescriber_drug_2024'` |
| `source_file` | TEXT | Full path of input file |
| `rows_read` | BIGINT | From input |
| `rows_inserted` | BIGINT | Into target table |
| `rows_rejected` | BIGINT | Failed validation |
| `null_rate_json` | JSONB | Per-column null rates `{"col": 0.012}` |
| `duplicate_key_count` | INT | Duplicate PKs found before de-dup |
| `unmatched_joins` | JSONB | `{"drug_id": 1234}` unmatched FKs |
| `checksum` | TEXT | MD5 of source file |
| `notes` | TEXT | Free text for caveats |
| `etl_version` | TEXT | Git commit SHA of ETL code |

---

## Key Join Logic and Caveats

| Join | Method | Caveat |
|------|--------|--------|
| Formulary NDC → drug spend | Normalized generic name match | NDC not present in spend file; name match is fuzzy; match rate < 100% |
| Prescriber drug → dim_drug | Brand+generic name pair | Same drug may appear under multiple brand names |
| Orange Book → dim_drug | Ingredient/trade name match | Many-to-many; some drugs unmatched |
| CPSC enrollment → dim_plan | contract_id + plan_benefit_pkg_id | Exact join on CMS identifiers |
| Prescriber → dim_geography | state_abbr | NPI-level city not normalized to county |

---

## Measures Reference

| Measure | Source table | Honest label |
|---------|-------------|--------------|
| `SUM(tot_clms)` | fact_prescriber_drug | "Total aggregated claims (provider-drug records)" |
| `SUM(tot_drug_cst)` | fact_prescriber_drug | "Total drug cost (\$)" |
| `SUM(enrollment)` | fact_enrollment | "Enrollment cell sums (not unique beneficiaries)" |
| Distinct `gnrc_name` | dim_drug | "Distinct generic drug names" |
| Distinct `brnd_name` | dim_drug | "Distinct brand drug names" |
| Distinct `ndc11` | dim_drug | "Distinct 11-digit NDCs" |
| `COUNT(DISTINCT loe_date)` | fact_loe | "Drugs with an LOE/exclusivity date" |
