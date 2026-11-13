# Portfolio 2: Query Processing and Optimisation

## Files
| File | Purpose |
|---|---|
| `seed_large.sql` | Generates ~50k customers, ~60k loans, ~300k schedule rows, ~190k repayments |
| `queries.sql` | 9 business queries (joins, aggregates, CTEs, window functions, anti-join) |
| `explain_before_after.sql` | `EXPLAIN (ANALYZE, BUFFERS)` for the queries to optimise |
| `indexes.sql` | Indexes added after the baseline |
| `results/` | Saved plan output (`before_*.txt`, `after_*.txt`) |
| `screenshots/` | Screenshots of query output and plans |

## How to run
```bash
cd portfolio-2-query-optimisation
PSQL="docker compose -f ../docker-compose.yml exec -T postgres psql -U ifl -d ifl"

$PSQL < ../portfolio-1-database-design/schema.sql          # fresh schema, no extra indexes
$PSQL < seed_large.sql                                      # load big data
$PSQL < explain_before_after.sql | tee results/before_plans.txt   # BASELINE
$PSQL < indexes.sql                                         # add indexes
$PSQL < explain_before_after.sql | tee results/after_plans.txt    # AFTER
```
Run `queries.sql` interactively too and screenshot the result rows.

## Results
All numbers are `Execution Time` from `EXPLAIN (ANALYZE, BUFFERS)` on the generated dataset (50k customers, 80k applications, 60k loans, 300k schedule rows, 189k repayments). Full plans are in `results/before_plans.txt` and `results/after_plans.txt`.

| Query | Plan before | Time before | Plan after | Time after |
|---|---|---|---|---|
| Q8 applications for one customer | Seq Scan on loan_applications (79,999 rows removed by the filter) | 14.9 ms | Bitmap Index Scan on `idx_applications_customer` | 0.32 ms |
| Q1 overdue instalments (top 50) | Parallel Seq Scan on repayment_schedule | 112.4 ms | Bitmap Index Scan on partial index `idx_schedule_pending_due` | 89.4 ms |
| Q5 repayments for one loan | Parallel Seq Scan on repayments | 31.5 ms | Index Scan on `idx_repayments_loan` | 0.38 ms |

Screenshots: `screenshots/03-plans-before-indexes.png`, `04-indexes-created.png`, `05-plans-after-indexes.png`, and `06-business-query-q1-results.png`.

## Analysis
**Q8 and Q5 got dramatically faster (about 46x and 83x).** Both are lookups that return a handful of rows out of tens of thousands. Before the indexes PostgreSQL had no choice but to read every row and throw almost all of them away; the Q8 plan even says `Rows Removed by Filter: 79999` to return one row. PostgreSQL does not index foreign key columns on its own, so `customer_id` on the applications table and `loan_id` on repayments had nothing to use. Once I added them the planner jumped straight to the matching rows.

**Q1 only improved by about 20%, and I think that is the more interesting result.** The partial index on `due_date WHERE status = 'PENDING'` did get used (the plan changed from a sequential scan to a bitmap index scan), but the query still matches roughly 86,000 overdue rows, then sorts them all by days overdue and keeps 50. The sort is where the time goes, and an index on `due_date` cannot remove it. So the lesson for me was that an index helps you *find* rows, not sort a huge result. To really fix Q1 I would either limit the date window, add a supporting index that matches the sort order, or keep a summary table for overdue accounts.

**Why a partial index.** Only unpaid instalments are ever searched for arrears, and most instalments eventually get paid, so indexing just the PENDING rows keeps the index small and cheap to maintain.

**What indexes cost.** Every index makes inserts and updates slower and takes disk space. That matters here because repayments and schedule rows are written all the time, so I only added indexes for queries I could prove were slow, and did not index low-cardinality columns like `region` (four values) or `kyc_status`, where the planner would just scan the table anyway.

**Join methods.** The plans show nested loops with index scans on the primary keys of `loans`, `loan_applications` and `customers`, which suits a query that returns only 50 rows. `ANALYZE` after loading matters too, because the row estimates come from those statistics.
