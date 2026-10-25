-- =====================================================================
-- cafe_project — 02_profiling.sql
-- Purpose: measure the damage, column by column, before touching it.
--
-- Run order: 01_staging_load → 02_profiling (this file) → 03_clean
--            → 04_clean_cafe → 05_analysis → 06_reporting_views
--
-- Nothing here changes a row. The point is to know the size and shape
-- of the problem first, so the cleaning in 04 can be justified rather
-- than guessed at.
-- =====================================================================

use cafe_project;


-- ---------------------------------------------------------------------
-- v_dq_column_summary — how many bad values per column, one row total.
-- ---------------------------------------------------------------------

drop view if exists v_dq_column_summary;
create view v_dq_column_summary as
select
sum(case when ITEM in('ERROR','UNKNOWN','') then 1 else 0 end) as bad_item,
sum(case when QUANTITY in('ERROR','UNKNOWN','') then 1 else 0 end) as bad_quantity,
sum(case when PRICE_PER_UNIT in('ERROR','UNKNOWN','')then 1 else 0 end) as bad_price_per_unit,
sum(case when TOTAL_SPENT in('ERROR','UNKNOWN','') then 1 else 0 end) as bad_total,
sum(case when PAYMENT_METHOD in('ERROR','UNKNOWN','') then 1 else 0 end) as bad_payment_method,
sum(case when LOCATION in('ERROR','UNKNOWN','') then 1 else 0 end) as bad_location,
sum(case when TRANSACTION_DATE in('ERROR','UNKNOWN','') then 1 else 0 end) as bad_date
from stg_cafe;


-- ---------------------------------------------------------------------
-- v_dq_issue_detail — which placeholder appears in which column, and
-- how many times. The summary above says how bad; this says in what way.
--
-- The date branch is deliberately different: instead of matching the
-- three known placeholders it asks STR_TO_DATE to parse the value and
-- counts the failures. That catches malformed dates as well as
-- placeholders — and it returns exactly the same 460 rows, which is how
-- we know there are no alternative formats hiding in the column.
-- ---------------------------------------------------------------------

drop view if exists v_dq_issue_detail;
create view v_dq_issue_detail as
with cte_main as (
select
'item' as column_name, item as value , count(*) as qnt
from stg_cafe
where ITEM in('','UNKNOWN','ERROR')
group by item
union all
select
'quantity', QUANTITY,  count(*)
from stg_cafe
where QUANTITY in('','UNKNOWN','ERROR')
group by QUANTITY
union all
select
'price_per_unit', PRICE_PER_UNIT, count(*)
from stg_cafe
where PRICE_PER_UNIT in('','UNKNOWN','ERROR')
group by
PRICE_PER_UNIT
union all
select
'total_spent', TOTAL_SPENT,count(*)
from stg_cafe
where TOTAL_SPENT in ('','UNKNOWN','ERROR')
group by TOTAL_SPENT
union all
select
'payment_method', PAYMENT_METHOD , count(*)
from stg_cafe
where PAYMENT_METHOD in ('','UNKNOWN','ERROR')
group by PAYMENT_METHOD
union all
select
'location', LOCATION , count(*)
from stg_cafe
where LOCATION in ('','UNKNOWN','ERROR')
group by LOCATION
union all
select
'transaction_date', TRANSACTION_DATE, count(*)
from stg_cafe
where str_to_date(TRANSACTION_DATE,'%Y-%m-%d') is null
group by TRANSACTION_DATE
)
select
column_name,
value,
qnt,
sum(qnt) over(partition by column_name) as total_bad
from cte_main
order by total_bad desc;


/*---------------------------- VALIDATION ----------------------------*/
select * from v_dq_column_summary;
-- expected: item 969, quantity 479, price_per_unit 533, total 502,
--           payment_method 3178, location 3961, date 460

select * from v_dq_issue_detail;
/*---------------------------- VALIDATION ----------------------------*/
