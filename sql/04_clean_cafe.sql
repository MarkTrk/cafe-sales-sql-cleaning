-- =====================================================================
-- cafe_project — 04_clean_cafe.sql
-- Purpose: build the cleansed layer and recover what can be recovered.
--
-- Run order: 01_staging_load → 02_profiling → 03_clean → 04_clean_cafe
--
-- Placeholders ('', 'UNKNOWN', 'ERROR') become NULL. Every column gets
-- its real data type. Nothing is guessed: a value is only written where
-- it can be derived from the other two numeric columns, and every row
-- that was repaired is flagged with IS_RECOVERED = 1.
-- =====================================================================

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

-- ---------------------------------------------------------------------
-- dim_item — the product dimension, derived from the clean rows rather
-- than typed in by hand. Only rows where both the item and its price
-- survived cleaning are used.
-- ---------------------------------------------------------------------

drop table if exists dim_item;
create table dim_item as
select
ITEM,
PRICE_PER_UNIT,
count(*) as source_rows
from clean_cafe
where item is not null and PRICE_PER_UNIT is not null
group by ITEM , PRICE_PER_UNIT;

-- 1. Key: the item must be unique. If this ALTER succeeds, every product
--    appears exactly once — and therefore has exactly one price.
ALTER TABLE dim_item ADD CONSTRAINT pk_dim_item PRIMARY KEY (item);

-- 2. Rule: the price must be positive. A price of zero or less is not a
--    cheap product, it is a broken row, and the database should refuse it.
ALTER TABLE dim_item ADD CONSTRAINT chk_price_positive CHECK (price_per_unit > 0);

ALTER TABLE dim_item MODIFY price_per_unit DECIMAL(5,2) NOT NULL;

show global variables like '%safe_updates';
SET SQL_SAFE_UPDATES = 0;

-- ---------------------------------------------------------------------
-- Recovery, in three passes. The order matters: filling the price first
-- unlocks rows whose quantity or total can then be derived from it.
-- ---------------------------------------------------------------------

/* PASS 0 — price from dim_item, where the item is known */
update clean_cafe cc
join dim_item di
on  cc.ITEM = di.ITEM
set cc.PRICE_PER_UNIT = di.PRICE_PER_UNIT, cc.IS_RECOVERED = 1
where cc.price_per_unit IS NULL;

/* PASS 1 — quantity from total / price */
update clean_cafe
set QUANTITY  = TOTAL_SPENT / PRICE_PER_UNIT,
	IS_RECOVERED = 1
where QUANTITY is null  and (TOTAL_SPENT is not null and PRICE_PER_UNIT is not null );

/* PASS 2 — total from quantity * price */
update clean_cafe
set TOTAL_SPENT =  QUANTITY * PRICE_PER_UNIT,
	IS_RECOVERED = 1
where TOTAL_SPENT is null and (QUANTITY is not null and PRICE_PER_UNIT is not null);


/*---------------------------- VALIDATION ----------------------------*/
SELECT * FROM cafe_project.clean_cafe;

SELECT count(*) FROM cafe_project.clean_cafe;
-- expected: 10000

SELECT sum(IS_RECOVERED) FROM cafe_project.clean_cafe;
-- 1398 before the three update passes, 1430 after

SELECT * FROM cafe_project.clean_cafe where QUANTITY * PRICE_PER_UNIT <> TOTAL_SPENT;
-- expected: empty, both before and after the updates

SELECT
 count(*) - count(ITEM)             as item_nulls_remaining,
 count(*) - count(QUANTITY)         as quantity_nulls_remaining,
 count(*) - count(PRICE_PER_UNIT)   as price_per_unit_nulls_remaining,
 count(*) - count(TOTAL_SPENT)      as total_spent_nulls_remaining,
 count(*) - count(PAYMENT_METHOD)   as payment_method_nulls_remaining,
 count(*) - count(LOCATION)         as location_nulls_remaining,
 count(*) - count(TRANSACTION_DATE) as transaction_date_nulls_remaining,
 count(*) - count(IS_RECOVERED)     as is_recovered_nulls_remaining
 FROM cafe_project.clean_cafe;

-- Before any update:      969, 38, 40, 3178, 3961, 460
-- After PASS 0:           969, 38,  6, 40, 3178, 3961, 460
--   (the 40 remaining totals are what PASS 2 then fills)
-- Final:                  969, 23,  6, 23, 3178, 3961, 460
--
-- The 969 items, 3,178 payment methods, 3,961 locations and 460 dates
-- are unrecoverable by design — see the README for why each one is left
-- as NULL rather than guessed.
/*---------------------------- VALIDATION ----------------------------*/
