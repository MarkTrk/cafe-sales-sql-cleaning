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
count(*),
round(count(*) *100.0 / sum(count(*)) over(),2) as percentage
from cte_main
group by flagged
order by flagged
