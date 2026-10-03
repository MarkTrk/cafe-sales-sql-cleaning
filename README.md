# Cafe Sales — SQL data cleaning

This project cleans a 10,000-row Kaggle dataset of coffee shop transactions ([Cafe Sales — Dirty Data for Cleaning Training](https://www.kaggle.com/datasets/ahmedmohamed2003/cafe-sales-dirty-data-for-cleaning-training)). The raw data contains `ERROR` and `UNKNOWN` placeholders and empty values across every column. I rebuilt it in MySQL as a staging → clean pipeline and recovered 96.6% of the missing numeric values from relationships within the data.

Everything here is SQL. The scripts are the deliverable.

## The data problem

I assessed all eight columns. Every column except `transaction_id` contains `ERROR` and `UNKNOWN` placeholders or empty strings.

| Column | Invalid values | % of rows |
|---|---|---|
| location | 3,961 | 39.6% |
| payment_method | 3,178 | 31.8% |
| item | 969 | 9.7% |
| price_per_unit | 533 | 5.3% |
| total_spent | 502 | 5.0% |
| quantity | 479 | 4.8% |
| transaction_date | 460 | 4.6% |
| transaction_id | 0 | 0% |

Source: `02_profiling.sql` — see `v_dq_column_summary`.

Five columns are damaged below 10%, but `payment_method` and `location` are far worse. For the date column I also checked for malformed values, not just placeholders: `STR_TO_DATE()` fails on exactly the same 460 rows, so there are no impossible dates or alternative formats hiding in there.

The three numeric columns are linked by `total_spent = quantity × price_per_unit`, so missing values there can be derived from the remaining two. The damaged text columns have no such relationship.

## Approach

I built the pipeline in three stages.

First, `stg_cafe` holds the raw data as `VARCHAR`, so the load never fails and never silently changes a value. After the load I validated it: 10,000 rows, 0 warnings. I checked the max length of every column to make sure nothing was truncated.

The second stage is `clean_cafe`, which holds every column in the right data type. Placeholders became `NULL`, dates became `DATE`, money became `DECIMAL`. All cleaning happens here, so the raw layer stays intact and the whole pipeline can be rebuilt from scratch.

I also created `dim_item`, a table holding each item with its price, derived from the clean rows rather than typed in by hand. I set `item` as the primary key, which proves every item appears only once — and therefore has exactly one price.

I left unrecoverable values as `NULL`, which means "not known". I did not substitute zeros: a zero would be included in an average, a `NULL` is skipped.

## Recovery

The three numeric columns are linked by `total_spent = quantity × price_per_unit`. I verified this on every row where all three values are present: zero exceptions. Where exactly one value was missing, I calculated it from the other two.

Where the price itself was missing but the item was known, I filled it from `dim_item`. That unlocked a further 32 rows: once the price was known, the missing quantity or total could also be calculated.

This recovered 1,430 rows — 96.6% of the 1,514 missing numeric values. The remaining 52 are rows where two of the three values are missing, so nothing can be derived.

### Validation

| Check | Result |
|---|---|
| Row count | 10,000 |
| Rows repaired (`SUM(is_recovered)`) | 1,430 |
| `quantity × price_per_unit <> total_spent` | 0 rows |
| `is_recovered` nulls | 0 |

Remaining nulls: item 969, quantity 23, price_per_unit 6, total_spent 23, payment_method 3,178, location 3,961, transaction_date 460.

The numbers reconcile from both directions: 479 + 533 + 502 = 1,514 missing values, of which 52 remain — and those 52 are exactly the two missing fields in each of the 26 rows that had two gaps.

Every repaired row carries `is_recovered = 1`, so a calculated value can always be told apart from a recorded one.

## What I did not do

Some values cannot be recovered, and I left them as `NULL` rather than guess.

**Item.** Each product has one price, so the price can always be derived from the item. The reverse only works where the price is unique: 1.00, 1.50, 2.00 and 5.00 identify exactly one product, but 3.00 could be Juice or Cake, and 4.00 could be Smoothie or Sandwich. I did not guess those.

**Transaction date.** 460 dates are missing. `transaction_id` is a random seven-digit number, not a sequence, so the rows cannot be ordered in time and a missing date cannot be interpolated from its neighbours.

**Payment method and location.** No other column predicts them. These are lost: 3,178 and 3,961 rows.

For `location` I checked whether the missing rows are biased: the average basket of the unknown group (8.95) sits between the two known groups (8.80 and 9.03), so the gap appears random. For `payment_method` the same check is less clean — the unknown group's average basket (8.78) sits slightly below all three known methods (8.93–9.05). The gap is about 2% and close to what random variation produces at this sample size, but conclusions about the payment mix should be read with that caveat.

## Findings

- **Coffee sells the most units (3,536) but earns 7,072 — less than half of Salad's 17,345.** Salad sells fewer units and earns 2.5 times more. A decision based on units sold would back the wrong product.
- **An average Salad transaction is worth 15.10; a Cookie transaction 2.95.**
- **No seasonality.** Daily average revenue by month ranges from 221.85 to 245.10 — under 10%. In raw monthly totals February looks like the worst month (−8.4%), but that is the 28-day effect; normalised to a daily average it is +1.4% and the third best month.
- **No weekly pattern.** Daily average revenue ranges from 224.63 (Wednesday) to 238.49 (Thursday), a spread of 6.2%. 2023 contains 53 Sundays and 52 of every other weekday, so this is measured per day, not per weekday total.
- **Location does not affect spending.** In-store 9.03 vs takeaway 8.80 per transaction, with an identical basket size of about 3 units.
- **The three known payment methods split evenly:** 22.90%, 22.91% and 22.97% of revenue.

Unattributable revenue: 9.5% has no item, 4.7% has no date.

## Is this data real?

Four independent signals say it is generated rather than collected:

1. Damage is spread randomly across columns. 3,089 rows are fully intact, which matches what independent random corruption predicts (~3,000).
2. No seasonality — monthly daily averages vary by under 10%.
3. No weekly pattern — weekday daily averages vary by 6.2%.
4. In-store and takeaway split 3,017 to 3,022.

A real coffee shop would show a weekend effect at least. This does not make the dataset less useful for practising data cleaning, but it rules out drawing business conclusions from the patterns — because there are none.

## Files

| File | What it does |
|---|---|
| `01_staging_load.sql` | Creates the schema and `stg_cafe`, loads the CSV, validates the load |
| `02_profiling.sql` | Column-level damage: `v_dq_column_summary` (totals per column) and `v_dq_issue_detail` (which placeholder, how many times) |
| `03_profiling.sql` | Row-level damage: `v_dq_pct_report` (how many fields are missing per row) and `v_dq_fixable` (how many rows are recoverable) |
| `04_clean_cafe.sql` | Builds `clean_cafe` and `dim_item`, runs the recovery, validates the result |
| `05_analysis.sql` | The six questions above |

Run them in order. Each script drops and recreates what it builds, so the whole pipeline can be rebuilt from the raw CSV at any time.

**Requirements:** MySQL 8.0.16 or later (`CHECK` constraints are not enforced before that). `LOAD DATA LOCAL INFILE` needs `local_infile` enabled on the server and `OPT_LOCAL_INFILE=1` in the Workbench connection.
