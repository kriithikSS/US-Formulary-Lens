-- =============================================================================
-- schema.sql  —  US Formulary Lens star schema
-- PostgreSQL 16  |  Run as the app role (flens) or superuser
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions (required for trigram text search and GIN index support)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- ---------------------------------------------------------------------------
-- ETL audit (created first so loaders can write to it immediately)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS etl_audit (
    audit_id            SERIAL PRIMARY KEY,
    load_timestamp      TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_name         TEXT        NOT NULL,
    source_file         TEXT,
    rows_read           BIGINT,
    rows_inserted       BIGINT,
    rows_rejected       BIGINT,
    null_rate_json      JSONB,
    duplicate_key_count INT,
    unmatched_joins     JSONB,
    checksum            TEXT,
    notes               TEXT,
    etl_version         TEXT
);

-- ---------------------------------------------------------------------------
-- Dimensions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_period (
    period_id       SERIAL PRIMARY KEY,
    year            SMALLINT    NOT NULL,
    quarter         SMALLINT,                       -- NULL for annual files
    period_label    VARCHAR(10) NOT NULL UNIQUE,    -- '2024' or '2024-Q3'
    source_file     TEXT
);

CREATE TABLE IF NOT EXISTS dim_drug (
    drug_id                 SERIAL PRIMARY KEY,
    ndc11                   CHAR(11),               -- NULL if not available
    ndc_valid               BOOLEAN,                -- TRUE = 11 numeric digits
    brnd_name               TEXT,
    gnrc_name               TEXT,
    drug_name_normalized    TEXT,                   -- UPPER TRIM for joins
    rxcui                   TEXT,
    atc_code                TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial unique index on ndc11 (NULL rows are excluded, allowing multiple NULLs)
CREATE UNIQUE INDEX IF NOT EXISTS uq_drug_ndc ON dim_drug(ndc11) WHERE ndc11 IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_drug_normalized ON dim_drug (drug_name_normalized);
CREATE INDEX IF NOT EXISTS idx_drug_brnd       ON dim_drug USING gin (brnd_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_drug_gnrc       ON dim_drug USING gin (gnrc_name gin_trgm_ops);

CREATE TABLE IF NOT EXISTS dim_plan (
    plan_id                 SERIAL PRIMARY KEY,
    contract_id             VARCHAR(10)  NOT NULL,
    plan_benefit_pkg_id     SMALLINT     NOT NULL,
    contract_plan_key       VARCHAR(15)  NOT NULL UNIQUE,  -- contract_id-pbp
    plan_name               TEXT,
    organization_type       TEXT,
    parent_org              TEXT,
    part_d_flag             BOOLEAN      DEFAULT TRUE,
    service_area_states     TEXT[],                    -- array of state abbrs
    snp                     TEXT                       -- SNP type from SPUF PlanInfo
);

CREATE INDEX IF NOT EXISTS idx_plan_contract  ON dim_plan (contract_id);
CREATE INDEX IF NOT EXISTS idx_plan_parent    ON dim_plan (parent_org);

CREATE TABLE IF NOT EXISTS dim_geography (
    geo_id          SERIAL PRIMARY KEY,
    state_abbr      CHAR(2)      NOT NULL,
    state_fips      CHAR(2),
    state_name      TEXT,
    county_name     TEXT,
    county_fips     CHAR(5),
    geo_level       VARCHAR(10)  NOT NULL CHECK (geo_level IN ('state','county','national')),
    CONSTRAINT uq_geo_state_county UNIQUE (state_abbr, county_fips)
);

CREATE INDEX IF NOT EXISTS idx_geo_state  ON dim_geography (state_abbr);
CREATE INDEX IF NOT EXISTS idx_geo_fips   ON dim_geography (county_fips);

CREATE TABLE IF NOT EXISTS dim_prescriber_specialty (
    specialty_id    SERIAL PRIMARY KEY,
    prscrbr_type    TEXT         NOT NULL UNIQUE,
    prscrbr_type_src VARCHAR(10)
);

-- ---------------------------------------------------------------------------
-- Bridge: dim_formulary (links formulary_id to plans; one formulary → many plans)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_formulary (
    formulary_id    VARCHAR(8)  NOT NULL,
    plan_id         INT         NOT NULL REFERENCES dim_plan(plan_id),
    PRIMARY KEY (formulary_id, plan_id)
);

-- ---------------------------------------------------------------------------
-- Facts
-- ---------------------------------------------------------------------------

-- Formulary coverage  (grain: formulary_id × NDC × period)
CREATE TABLE IF NOT EXISTS fact_formulary_coverage (
    coverage_id         BIGSERIAL PRIMARY KEY,
    formulary_id        VARCHAR(8)   NOT NULL,       -- references dim_formulary implicitly
    drug_id             INT          REFERENCES dim_drug(drug_id),  -- NULL if NDC unmatched
    period_id           INT          NOT NULL REFERENCES dim_period(period_id),
    rxcui               CHAR(8),
    tier_level_value    SMALLINT,
    prior_auth_yn       BOOLEAN,
    step_therapy_yn     BOOLEAN,
    quantity_limit_yn   BOOLEAN,
    qty_limit_amount    SMALLINT,
    qty_limit_days      SMALLINT,
    selected_drug_yn    BOOLEAN,
    formulary_version   SMALLINT,
    contract_year       SMALLINT
);

CREATE INDEX IF NOT EXISTS idx_fcov_formulary ON fact_formulary_coverage (formulary_id);
CREATE INDEX IF NOT EXISTS idx_fcov_drug      ON fact_formulary_coverage (drug_id);
CREATE INDEX IF NOT EXISTS idx_fcov_period    ON fact_formulary_coverage (period_id);
CREATE INDEX IF NOT EXISTS idx_fcov_tier      ON fact_formulary_coverage (tier_level_value);
CREATE INDEX IF NOT EXISTS idx_fcov_pa        ON fact_formulary_coverage (prior_auth_yn);

-- Drug spend  (grain: drug × manufacturer × year)
CREATE TABLE IF NOT EXISTS fact_drug_spend (
    spend_id                    BIGSERIAL PRIMARY KEY,
    drug_id                     INT          REFERENCES dim_drug(drug_id),
    period_id                   INT          NOT NULL REFERENCES dim_period(period_id),
    year                        SMALLINT     NOT NULL,
    mftr_name                   TEXT,
    tot_spndng                  NUMERIC(18,2),
    tot_dsg_unts                BIGINT,
    tot_clms                    BIGINT,
    tot_benes                   INT,
    avg_spnd_per_clm            NUMERIC(12,4),
    avg_spnd_per_dsg_unt_wghtd  NUMERIC(12,6),
    avg_spnd_per_bene           NUMERIC(12,4),
    outlier_flag                BOOLEAN,
    bene_suppression_flag       BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_spend_drug    ON fact_drug_spend (drug_id);
CREATE INDEX IF NOT EXISTS idx_spend_period  ON fact_drug_spend (period_id);
CREATE INDEX IF NOT EXISTS idx_spend_year    ON fact_drug_spend (year);

-- Prescriber × Drug  (grain: NPI × drug name × year)
CREATE TABLE IF NOT EXISTS fact_prescriber_drug (
    pd_id                   BIGSERIAL PRIMARY KEY,
    npi                     CHAR(10)     NOT NULL,
    prscrbr_last_org_name   TEXT,
    prscrbr_first_name      TEXT,
    geo_id                  INT          REFERENCES dim_geography(geo_id),
    specialty_id            INT          REFERENCES dim_prescriber_specialty(specialty_id),
    drug_id                 INT          REFERENCES dim_drug(drug_id),
    period_id               INT          NOT NULL REFERENCES dim_period(period_id),
    tot_clms                INT,
    tot_30day_fills         NUMERIC(10,1),
    tot_day_suply           BIGINT,
    tot_drug_cst            NUMERIC(14,2),
    tot_benes               INT,
    ge65_sprsn_flag         CHAR(1),     -- '#' or NULL
    ge65_bene_sprsn_flag    CHAR(1),     -- '*' or NULL
    ge65_tot_clms           INT,         -- NULL when suppressed
    ge65_tot_30day_fills    NUMERIC(10,1),
    ge65_tot_drug_cst       NUMERIC(14,2),
    ge65_tot_day_suply      BIGINT,
    ge65_tot_benes          INT
);

CREATE INDEX IF NOT EXISTS idx_pd_npi      ON fact_prescriber_drug (npi);
CREATE INDEX IF NOT EXISTS idx_pd_drug     ON fact_prescriber_drug (drug_id);
CREATE INDEX IF NOT EXISTS idx_pd_geo      ON fact_prescriber_drug (geo_id);
CREATE INDEX IF NOT EXISTS idx_pd_period   ON fact_prescriber_drug (period_id);
CREATE INDEX IF NOT EXISTS idx_pd_spec     ON fact_prescriber_drug (specialty_id);

-- Geography × Drug  (grain: state/national × drug name × year)
CREATE TABLE IF NOT EXISTS fact_geo_drug (
    geo_drug_id             BIGSERIAL PRIMARY KEY,
    geo_id                  INT          NOT NULL REFERENCES dim_geography(geo_id),
    drug_id                 INT          REFERENCES dim_drug(drug_id),
    period_id               INT          NOT NULL REFERENCES dim_period(period_id),
    brnd_name               TEXT,
    gnrc_name               TEXT,
    tot_prscrbrs            INT,
    tot_clms                BIGINT,
    tot_30day_fills         NUMERIC(12,1),
    tot_drug_cst            NUMERIC(18,2),
    tot_benes               INT,
    ge65_sprsn_flag         CHAR(1),
    ge65_tot_clms           BIGINT,
    ge65_tot_30day_fills    NUMERIC(12,1),
    ge65_tot_drug_cst       NUMERIC(18,2),
    ge65_bene_sprsn_flag    CHAR(1),
    ge65_tot_benes          INT,
    lis_bene_cst_shr        NUMERIC(14,2),
    nonlis_bene_cst_shr     NUMERIC(14,2),
    opioid_drug_flag        BOOLEAN,
    opioid_la_drug_flag     BOOLEAN,
    antbtc_drug_flag        BOOLEAN,
    antpsyct_drug_flag      BOOLEAN
);

CREATE INDEX IF NOT EXISTS idx_gd_geo     ON fact_geo_drug (geo_id);
CREATE INDEX IF NOT EXISTS idx_gd_drug    ON fact_geo_drug (drug_id);
CREATE INDEX IF NOT EXISTS idx_gd_period  ON fact_geo_drug (period_id);

-- Enrollment  (grain: contract × plan × state × county × month)
CREATE TABLE IF NOT EXISTS fact_enrollment (
    enroll_id           BIGSERIAL PRIMARY KEY,
    plan_id             INT          REFERENCES dim_plan(plan_id),
    geo_id              INT          REFERENCES dim_geography(geo_id),
    period_id           INT          NOT NULL REFERENCES dim_period(period_id),
    ssa_county_code     CHAR(5),
    enrollment          INT,          -- NULL when masked ('*')
    enrollment_masked   BOOLEAN      DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_enroll_plan    ON fact_enrollment (plan_id);
CREATE INDEX IF NOT EXISTS idx_enroll_geo     ON fact_enrollment (geo_id);
CREATE INDEX IF NOT EXISTS idx_enroll_period  ON fact_enrollment (period_id);

-- LOE / Exclusivity  (grain: application × patent/exclusivity code)
CREATE TABLE IF NOT EXISTS fact_loe (
    loe_id              SERIAL PRIMARY KEY,
    drug_id             INT          REFERENCES dim_drug(drug_id),  -- best-effort match
    appl_no             VARCHAR(10),
    product_no          VARCHAR(10),
    ingredient          TEXT,
    trade_name          TEXT,
    applicant           TEXT,
    strength            TEXT,
    appl_type           CHAR(1),     -- N=NDA, A=ANDA
    patent_no           TEXT,
    exclusivity_code    TEXT,        -- NCE, ODE, M, etc.
    exclusivity_date    DATE,
    patent_expire_date  DATE,
    loe_type            VARCHAR(15)  CHECK (loe_type IN ('patent','exclusivity'))
);

CREATE INDEX IF NOT EXISTS idx_loe_drug         ON fact_loe (drug_id);
CREATE INDEX IF NOT EXISTS idx_loe_excl_date    ON fact_loe (exclusivity_date);
CREATE INDEX IF NOT EXISTS idx_loe_patent_date  ON fact_loe (patent_expire_date);

-- ---------------------------------------------------------------------------
-- Materialized views (Phase 4 — created by dashboard setup script)
-- ---------------------------------------------------------------------------
-- mv_state_spend       : state-level spend and claims aggregates
-- mv_top_drugs_spend   : top 100 drugs by total spend
-- mv_formulary_summary : plan-level PA/ST/QL rates by tier
-- (Created via sql/create_materialized_views.sql in Phase 4)
