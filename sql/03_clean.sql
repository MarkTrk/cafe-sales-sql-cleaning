-- =====================================================================
-- cafe_project — 03_clean.sql
-- Purpose: measure the damage per ROW, not per column.
--
-- Run order: 01_staging_load → 02_profiling → 03_clean (this file)
--            → 04_clean_cafe → 05_analysis → 06_reporting_views
--
-- 02 counts bad values down each column. This file counts them across
-- each row, which answers a different question: how many rows are
-- untouched, how many have one gap, how many are beyond repair.
--
-- v_dq_fixable then narrows that to the three numeric columns, because
-- those are the only ones where a missing value can be derived from the
-- others. That count is what 04 is expected to recover.
-- =====================================================================

use cafe_project;


-- ---------------------------------------------------------------------
-- v_dq_pct_report — distribution of rows by how many fields are missing.
-- ---------------------------------------------------------------------

drop view if exists v_dq_pct_report;
create view v_dq_pct_report as
with cte_flagged as (
 SELECT
TRANSACTION_ID,
ITEM,
QUANTITY,
PRICE_PER_UNIT,
TOTAL_SPENT,
PAYMENT_METHOD,
LOCATION,
TRANSACTION_DATE,
case when ITEM  in ('','ERROR','UNKNOWN') then 1 else 0 end
+
case when QUANTITY  in ('','ERROR','UNKNOWN') then 1 else 0 end
+
case when PRICE_PER_UNIT  in ('','ERROR','UNKNOWN') then 1 else 0 end
+
case when TOTAL_SPENT  in ('','ERROR','UNKNOWN') then 1 else 0 end
+
case when PAYMENT_METHOD  in ('','ERROR','UNKNOWN') then 1 else 0 end
+
case when LOCATION  in ('','ERROR','UNKNOWN') then 1 else 0 end
+
case when TRANSACTION_DATE  in ('','ERROR','UNKNOWN') then 1 else 0 end
as missing_fields
 FROM cafe_project.stg_cafe
 )
 select
 missing_fields,
 count(*) as row_count,
 SUM(COUNT(*)) OVER () AS grand_total,
 round(count(*) *100.0 / sum(count(*)) over(),2) as percentage
 from cte_flagged
 group by missing_fields
 order by missing_fields;


-- ---------------------------------------------------------------------
-- v_dq_fixable — the same idea, narrowed to quantity, price and total.
--
-- flagged = 0  → nothing missing, nothing to do
-- flagged = 1  → recoverable: the other two values give the third
-- flagged = 2+ → not recoverable from within the row
-- ---------------------------------------------------------------------

drop view if exists v_dq_fixable;
create view v_dq_fixable as
with cte_main as (
SELECT
	TRANSACTION_ID,
    ITEM,
    QUANTITY,
    PRICE_PER_UNIT,
    TOTAL_SPENT,
    PAYMENT_METHOD,
    LOCATION,
    TRANSACTION_DATE,
    case when QUANTITY in ('','UNKNOWN','ERROR') then 1 else 0 end
    +
    case when PRICE_PER_UNIT in ('','UNKNOWN','ERROR') then 1 else 0 end
    +
	case when TOTAL_SPENT in ('','UNKNOWN','ERROR') then 1 else 0 end
    as flagged
FROM cafe_project.stg_cafe
)
select
flagged,
count(*) as row_count,
round(count(*) *100.0 / sum(count(*)) over(),2) as percentage
from cte_main
group by flagged
order by flagged;


/*---------------------------- VALIDATION ----------------------------*/
select * from v_dq_pct_report;
-- 3,089 rows are fully intact, which is close to what independent
-- random corruption across seven columns would predict (~3,000)

select * from v_dq_fixable;
-- flagged = 1 is the number of rows 04 should be able to recover
/*---------------------------- VALIDATION ----------------------------*/
