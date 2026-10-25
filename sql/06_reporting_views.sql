-- =====================================================================
-- cafe_project — 06_reporting_views.sql
-- Purpose: the reporting layer that Power BI connects to.
--
-- Run order: 01_staging_load → 02_profiling → 03_clean → 04_clean_cafe
--            → 05_analysis → 06_reporting_views (this file)
--
-- Depends on: clean_cafe and dim_item, both built in 04_clean_cafe.sql.
-- This file creates views only, so it can be re-run at any time without
-- touching the data.
--
-- -------------------------------------------------------------------
-- THE LAYER DECISION THIS FILE EXISTS TO ENFORCE
--
-- clean_cafe keeps NULL where a value is genuinely missing. That is the
-- truth, and the data quality views in 02 and 03 measure it.
--
-- 'Unknown' is a REPORTING label, not a fact. It is created here and
-- nowhere else, so a chart can show the gap as a category without the
-- cleansed layer ever pretending to know something it doesn't.
--
-- In one sentence: cleansing removes noise, reporting adds labels, and
-- the two never happen in the same layer.
-- =====================================================================

use cafe_project;


-- ---------------------------------------------------------------------
-- 1. v_cafe_sales — the fact view
--
-- Identical to clean_cafe row for row. The only change is that the three
-- text columns that can be missing get the label 'Unknown' instead of
-- NULL, so a chart can draw the gap as its own bar.
--
-- COALESCE is applied to text columns ONLY. On a numeric or date column
-- it would coerce the type and destroy the aggregation — SUM, the date
-- hierarchy and every time intelligence measure would break.
--
-- TRANSACTION_DATE therefore keeps its NULLs. The 4,174 of undated
-- revenue is shown on page 3 of the report rather than hidden here.
-- ---------------------------------------------------------------------

create or replace view v_cafe_sales as
select
    TRANSACTION_ID,
    coalesce(ITEM,           'Unknown')  as ITEM,
    QUANTITY,
    PRICE_PER_UNIT,
    TOTAL_SPENT,
    coalesce(PAYMENT_METHOD, 'Unknown')  as PAYMENT_METHOD,
    coalesce(LOCATION,       'Unknown')  as LOCATION,
    TRANSACTION_DATE,
    IS_RECOVERED
from clean_cafe;


-- ---------------------------------------------------------------------
-- 2. v_dim_item — the dimension view
--
-- Power BI filters and groups from this view, not from the fact table.
-- Separating them is what makes ALL('dim_item'[ITEM]) work in DAX: the
-- filter originates in the dimension, so that is the only place it can
-- be removed. Blocking the fact column removes nothing and silently
-- returns 100%.
--
-- dim_item itself cannot hold an 'Unknown' row: price_per_unit is
-- NOT NULL and must be positive, and an unidentified product has no
-- price. Those constraints are correct and stay.
--
-- The label is added here instead, with UNION ALL. Without this row the
-- fact rows whose ITEM is 'Unknown' would have no match in the dimension,
-- and Power BI would quietly route them to an auto-generated blank row.
--
-- Column names in a UNION come from the first SELECT, so the aliases in
-- the second are for the reader, not the engine.
-- ---------------------------------------------------------------------

create or replace view v_dim_item as
select
    ITEM,
    price_per_unit
from dim_item

union all

select
    'Unknown'  as ITEM,
    null       as price_per_unit;


-- ---------------------------------------------------------------------
-- 3. Access
--
-- Power BI connects through a read-only service account scoped to this
-- schema. It is never the root account, and it has no rights outside
-- cafe_project.
--
--   create user 'powerbi'@'localhost' identified by '<password>';
--   grant select on cafe_project.* to 'powerbi'@'localhost';
--
-- GRANT SELECT ON cafe_project.* covers every current and future object
-- in the schema, so the two views above need no separate grant.
--
-- Note: 'powerbi'@'localhost' and 'powerbi'@'127.0.0.1' are different
-- accounts in the MySQL grant tables. If the connection is made by IP
-- rather than by name, the host part has to match.
-- ---------------------------------------------------------------------
