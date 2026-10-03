SELECT * FROM cafe_project.clean_cafe;
/*
1. Melyik termék hozza a bevételt?
Tranzakciószám, eladott darab és bevétel termékenként. Technika: GROUP BY, SUM, ORDER BY.
Miért érdekes: a legkelendőbb és a legjövedelmezőbb termék ritkán ugyanaz.

*/
select
ITEM,
sum(QUANTITY) as sold_amount,
sum(TOTAL_SPENT) as total_income_by_item,
count(TOTAL_SPENT) as total_coverage,
count(*) as tota_transaction_by_item,
round(sum(TOTAL_SPENT) / count(*),2) as average_spent_by_customer_on_item,
ROUND(SUM(total_spent) / SUM(SUM(total_spent)) OVER () * 100, 1) AS revenue_share_pct
from clean_cafe
group by ITEM
order by  total_income_by_item desc;

/*2. Hogyan alakul a bevétel havonta?
Havi bevétel, és az előző hónaphoz képesti változás. Technika: MONTH(), és a változáshoz LAG() window function.
Miért érdekes: van-e szezonalitás, vagy egyenletes az év.*/

with cte_main as(
select
date_format(TRANSACTION_DATE,'%Y-%m')as sales_month,
sum(TOTAL_SPENT) as TOTAL_INCOME,
count(*) as TOTAL_ROW,
round(SUM(total_spent) / DAY(LAST_DAY(MAX(transaction_date))),2)  AS avg_daily_income
from clean_cafe
WHERE transaction_date IS NOT NULL
group by sales_month
order by sales_month
)
select
  *,
  LAG(avg_daily_income) OVER (ORDER BY sales_month) AS prev_avg_daily,
  ROUND((avg_daily_income - LAG(avg_daily_income) OVER (ORDER BY sales_month))
        / LAG(avg_daily_income) OVER (ORDER BY sales_month) * 100, 1) AS mom_change_pct
from cte_main
order by sales_month;

/*3. Mely napokon forgalmasabb a kávézó?
Hét napja szerinti átlagos napi bevétel. Technika: DAYOFWEEK(), AVG.
Miért érdekes: ebből következik a műszakbeosztás.*/

select
  dayname(transaction_date) as day_name,
  count(*) as transactions,
  sum(total_spent) as revenue,
  avg(total_spent) as avg_basket,
  sum(TOTAL_SPENT) / count(distinct TRANSACTION_DATE) as avg_daily_revenue
from clean_cafe
where transaction_date is not null
group by dayname(transaction_date), dayofweek(transaction_date)
order by dayofweek(transaction_date);

/*4. Mekkora egy átlagos vásárlás, és különbözik-e a helyszín szerint?
Átlagos tranzakcióérték és átlagos darabszám, takeaway vs in-store bontásban.
Miért érdekes: ha az in-store kosár nagyobb, az az ültetés értékét mutatja.*/

select
 COALESCE(location, 'Unknown') as location,
count(*) as transactions,
 round(avg(TOTAL_SPENT),2) as average_spent,
round(avg(QUANTITY),2) as average_qty
from clean_cafe 
group by LOCATION;


/*6. Fizetési módok megoszlása — de csak az adathiány kimondásával (32% ismeretlen). Ez inkább a módszertani őszinteségedet mutatja, mint üzleti felismerést.*/

select
coalesce(PAYMENT_METHOD,'Unknown') as payment_method,
count(*) as transactions,
avg(TOTAL_SPENT) as average_basket,
sum(TOTAL_SPENT) as income,
round(sum(TOTAL_SPENT)/ sum(sum(TOTAL_SPENT)) over() * 100,2) as income_percentage,
round(count(*) / sum(count(*)) over() * 100 ,2) as transactions_percentage 
from clean_cafe
group by payment_method

/*The most common transaction is digital wallet only after  the unknown transactions.
3178 of transcaction is unknown how it has been paid  witch is 31.8 percent,1/3 of the transactions and ,
31.2 percent of the income of the year.
 Between the 3 correct payment method the spread  is negligible not even 1 percent, they share evenly.
 It is also indicateing the date has been generated rother than  a real data from a coffe shop.*/

















