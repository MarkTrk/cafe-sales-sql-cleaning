-- =====================================================================
-- cafe_project — 01_staging_load.sql
-- Purpose: load the raw CSV into a staging table without judgment.
--
-- Run order: 01_staging_load (this file) → 02_profiling → 03_clean
--            → 04_clean_cafe → 05_analysis → 06_reporting_views
--
-- Every column is VARCHAR here. The load therefore never fails on a bad
-- value and never silently changes one: 'ERROR', 'UNKNOWN' and empty
-- strings all arrive exactly as they are in the file. Judging them is
-- 02's job, cleaning them is 04's.
-- =====================================================================

create database if not exists cafe_project;
use cafe_project;

-- Transaction ID | Item | Quantity | Price Per Unit | Total Spent
--                | Payment Method | Location | Transaction Date

drop table if exists stg_cafe;
create table  stg_cafe (
TRANSACTION_ID varchar(30),
ITEM varchar(30),
QUANTITY varchar(30),
PRICE_PER_UNIT varchar(30),
TOTAL_SPENT varchar(30),
PAYMENT_METHOD varchar(30),
LOCATION varchar(30),
TRANSACTION_DATE varchar(30)
);

SHOW GLOBAL VARIABLES LIKE 'local_infile';
set global local_infile = 1;

-- Change this path to wherever you saved the CSV. In this repo it is
-- data/dirty_cafe_sales.csv.
-- Source: https://www.kaggle.com/datasets/ahmedmohamed2003/cafe-sales-dirty-data-for-cleaning-training
load data local infile 'C:/data/project2/dirty_cafe_sales.csv'
into table stg_cafe
char set utf8mb4
fields
terminated by ','
enclosed by '"'
lines
starting by '' -- default
terminated by '\r\n'
ignore  1 lines;


/*---------------------------- VALIDATION ----------------------------*/
select count(*) as rows_loaded from stg_cafe;
-- expected: 10000, 0 warnings

select
  max(length(TRANSACTION_ID))   as max_transaction_id,
  max(length(ITEM))             as max_item,
  max(length(QUANTITY))         as max_quantity,
  max(length(PRICE_PER_UNIT))   as max_price_per_unit,
  max(length(TOTAL_SPENT))      as max_total_spent,
  max(length(PAYMENT_METHOD))   as max_payment_method,
  max(length(LOCATION))         as max_location,
  max(length(TRANSACTION_DATE)) as max_transaction_date
from stg_cafe;
-- every value must be under 30 characters, or something was truncated
/*---------------------------- VALIDATION ----------------------------*/
