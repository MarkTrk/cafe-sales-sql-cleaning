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
;

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



