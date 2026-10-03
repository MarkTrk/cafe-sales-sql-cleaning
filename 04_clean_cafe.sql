drop table if exists clean_cafe;
create table clean_cafe (
TRANSACTION_ID  char(11) primary key,
ITEM varchar(8) ,
QUANTITY  tinyint ,
PRICE_PER_UNIT decimal(5,2) ,
TOTAL_SPENT decimal(5,2) ,
PAYMENT_METHOD VARCHAR(20)
	constraint chk_payment_method
    check (payment_method IN ('Credit Card','Cash','Digital Wallet')),
LOCATION varchar(8)
	constraint chk_location 
    check(LOCATION in('Takeaway','In-store')),
TRANSACTION_DATE date,
IS_RECOVERED tinyint
);

insert into clean_cafe (TRANSACTION_ID,ITEM,QUANTITY,PRICE_PER_UNIT,TOTAL_SPENT,PAYMENT_METHOD,LOCATION,TRANSACTION_DATE,IS_RECOVERED)
with cte_parameter_values as (
select 
 TRANSACTION_ID,
 case when ITEM in('','UNKNOWN','ERROR') then null else ITEM end  as ITEM,
 case when QUANTITY in('','UNKNOWN','ERROR') then null else cast(QUANTITY as unsigned) end as QUANTITY,
 case when PRICE_PER_UNIT in('','UNKNOWN','ERROR') then null else cast(PRICE_PER_UNIT as decimal(5,2)) end as PRICE_PER_UNIT,
 case when TOTAL_SPENT in('','UNKNOWN','ERROR') then null else cast(TOTAL_SPENT as decimal(5,2)) end as TOTAL_SPENT,
 case when PAYMENT_METHOD in('','UNKNOWN','ERROR') then null else PAYMENT_METHOD end as PAYMENT_METHOD,
 case when LOCATION in('','UNKNOWN','ERROR') then null else LOCATION end as LOCATION,
 case when TRANSACTION_DATE in('','UNKNOWN','ERROR') then null else str_to_date(TRANSACTION_DATE,'%Y-%m-%d') end as TRANSACTION_DATE
from stg_cafe
),
cte_is_recovered as (
select
TRANSACTION_ID,
ITEM,
case when QUANTITY is not null then QUANTITY
	 when QUANTITY is null and (PRICE_PER_UNIT is not null and TOTAL_SPENT is not null) then TOTAL_SPENT / PRICE_PER_UNIT
	 else  null
end as QUANTITY,
case when PRICE_PER_UNIT is not null then PRICE_PER_UNIT
	 when PRICE_PER_UNIT is null and (QUANTITY is not null and TOTAL_SPENT is not null ) then TOTAL_SPENT / QUANTITY
	 else null
end as PRICE_PER_UNIT,
case when TOTAL_SPENT is not null then TOTAL_SPENT 
	 when TOTAL_SPENT is null and (QUANTITY is not null and PRICE_PER_UNIT is not null) then QUANTITY * PRICE_PER_UNIT
	 else null
end as TOTAL_SPENT,
PAYMENT_METHOD,
LOCATION,
TRANSACTION_DATE,
case when  QUANTITY is null then 1 else 0 end 
+
case when  PRICE_PER_UNIT is null then 1 else 0 end 
+
case when TOTAL_SPENT is null then 1 else 0 end 
as missing_numeric
from cte_parameter_values
)
select
TRANSACTION_ID,
ITEM,
QUANTITY,
PRICE_PER_UNIT,
TOTAL_SPENT,
PAYMENT_METHOD,
LOCATION,
TRANSACTION_DATE,
case when missing_numeric = 1 then 1 else 0 end as IS_RECOVERED
from cte_is_recovered
;
 show global variables like '%safe_updates';
SET SQL_SAFE_UPDATES = 0;
/*update 0*/
update clean_cafe 
set  PRICE_PER_UNIT = case
							when item  = 'Cookie' then 1.00
                            when item = 'Tea' then 1.50
                            when item = 'Coffee' then 2.00
                            when item = 'Juice' then 3.00
                            when item = 'Cake' then 3.00
                            when item = 'Smoothie' then 4.00
                            when item = 'Sandwich' then 4.00
							when item = 'Salad' then 5.00
                            else PRICE_PER_UNIT end, 
                            IS_RECOVERED = 1
where price_per_unit IS NULL AND item IS NOT NULL;

/*UPDATE 1*/
update clean_cafe
set QUANTITY  = TOTAL_SPENT / PRICE_PER_UNIT,
	IS_RECOVERED = 1
where QUANTITY is null  and (TOTAL_SPENT is not null and PRICE_PER_UNIT is not null );

/*UPDATE2*/
update clean_cafe 
set TOTAL_SPENT =  QUANTITY * PRICE_PER_UNIT,
	IS_RECOVERED = 1
where TOTAL_SPENT is null and (QUANTITY is not null and PRICE_PER_UNIT is not null);


/*----------------VVALIDATION----------------------------------*/
SELECT * FROM cafe_project.clean_cafe;
SELECT count(*) FROM cafe_project.clean_cafe;  -- 10000;
SELECT sum(IS_RECOVERED) FROM cafe_project.clean_cafe; -- 1398 , after update it is 1430;
SELECT * FROM cafe_project.clean_cafe  where QUANTITY * PRICE_PER_UNIT <> TOTAL_SPENT; -- empty table, after update still empty;
SELECT
 count(*) - count(ITEM) as item_is_null_reamin,
 count(*) - count(QUANTITY) as quantity_is_null_reamin,
 count(*) - count(PRICE_PER_UNIT) as price_per_unit_is_null_reamin,
 count(*) - count(TOTAL_SPENT) as total_spent_is_null_reamin,
 count(*) - count(PAYMENT_METHOD) as payment_method_is_null_reamin,
 count(*) - count(LOCATION) as location_is_null_reamin,
 count(*) - count(TRANSACTION_DATE) as transaction_date_is_null_reamin,
 count(*) - count(IS_RECOVERED) as IS_RECOVERED_is_null_reamin
 
 FROM cafe_project.clean_cafe;												-- (969,38,40,3178,3961,460),(after update 969,38,6,40 gondolom ez   a 40 amit a kövi update kezel ,3178,3961,460)
																			-- last validation resoult is (969,23,6,23,3178,3961,460)
 /*----------------VVALIDATION----------------------------------*/