-- =====================================================================
-- cafe_project — 05_analysis.sql
-- Purpose: the business questions, answered against the cleansed layer.
--
-- Run order: 01_staging_load → 02_profiling → 03_clean → 04_clean_cafe
--            → 05_analysis
--
-- Every query runs on clean_cafe, so NULL still means "not known".
-- Where a missing value would distort the answer, it is shown as its
-- own group rather than dropped.
-- =====================================================================

SELECT * FROM cafe_project.clean_cafe;


/* ---------------------------------------------------------------------
   1. Which product brings in the revenue?

   Transactions, units sold and revenue per product.
   Technique: GROUP BY, SUM, ORDER BY, window function for the share.

   Why it matters: the best-selling product and the most profitable one
   are rarely the same, and a decision based on units sold would back
   the wrong one.
   ------------------------------------------------------------------ */

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


/* ---------------------------------------------------------------------
   2. How does revenue move month by month?

   Monthly revenue and the change against the previous month.
   Technique: DATE_FORMAT for the grouping, LAG() for the comparison.

   Why it matters: is there seasonality, or is the year flat?

   Note: the comparison is made on the average DAILY revenue, not the
   monthly total. February has 28 days, so a raw monthly total makes it
   look like the worst month when it is not.
   ------------------------------------------------------------------ */

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


/* ---------------------------------------------------------------------
   3. Which days are busier?

   Average daily revenue by day of the week.
   Technique: DAYNAME(), DAYOFWEEK() for the sort order.

   Why it matters: shift planning follows from this.

   Note: 2023 contains 53 Sundays and 52 of every other weekday, so this
   is measured per day, not as a weekday total.
   ------------------------------------------------------------------ */

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


/* ---------------------------------------------------------------------
   4. What is an average purchase worth, and does it differ by location?

   Average transaction value and average basket size, takeaway against
   in-store.

   Why it matters: a larger in-store basket would be the measurable
   value of seating.

   The missing locations are grouped as 'Unknown' rather than dropped,
   because they are 39.6% of the rows and leaving them out would hide
   the size of the gap.
   ------------------------------------------------------------------ */

select
 COALESCE(location, 'Unknown') as location,
count(*) as transactions,
 round(avg(TOTAL_SPENT),2) as average_spent,
round(avg(QUANTITY),2) as average_qty
from clean_cafe
group by LOCATION;


/* ---------------------------------------------------------------------
   5. How does the payment mix split — with the gap stated?

   Share of transactions and share of revenue per payment method, with
   the unknown group shown as its own row.

   This one is about methodological honesty rather than a business
   insight: a third of the payment methods are simply not recorded.
   ------------------------------------------------------------------ */

select
coalesce(PAYMENT_METHOD,'Unknown') as payment_method,
count(*) as transactions,
avg(TOTAL_SPENT) as average_basket,
sum(TOTAL_SPENT) as income,
round(sum(TOTAL_SPENT)/ sum(sum(TOTAL_SPENT)) over() * 100,2) as income_percentage,
round(count(*) / sum(count(*)) over() * 100 ,2) as transactions_percentage
from clean_cafe
group by payment_method;

/* Digital wallet is the most common recorded method — but only after
   the unknown group, which is larger than any of them.

   3,178 transactions have no recorded payment method: 31.8% of the
   transactions and 31.2% of the year's revenue.

   Across the three recorded methods the spread is under one percentage
   point, so they split almost perfectly evenly. That is another signal
   that the data was generated rather than collected from a real coffee
   shop, where one method would normally dominate. */
