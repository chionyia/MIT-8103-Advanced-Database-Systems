# Portfolio 1: Database Design and Modelling

## Case study
**InterestFree Lend** is a simulated fintech platform offering interest-free (Qard Hasan style) loans to individuals and small traders.
See the root [README](../README.md) for the full case-study statement.

## Files
| File | Purpose |
|---|---|
| `er-diagram.md` | ER diagram (Mermaid) and relationship notes |
| `schema.sql` | Complete DDL: tables, PKs, FKs, UNIQUE, CHECK, DEFAULT constraints |
| `seed.sql` | Small sample dataset |
| `screenshots/` | ER diagram image, schema creation output, `\dt` / `\d` output |

## How to run
```bash
# from repo root: start PostgreSQL
docker compose up -d postgres
docker compose exec -T postgres psql -U ifl -d ifl < portfolio-1-database-design/schema.sql
docker compose exec -T postgres psql -U ifl -d ifl < portfolio-1-database-design/seed.sql
docker compose exec postgres psql -U ifl -d ifl -c '\dt'
```

## Design decisions
- **No interest columns**: the central business rule is modelled structurally. The schedule holds equal instalments of principal only.
- **`fund_pool.balance CHECK (balance >= 0)`**: the database itself prevents over-lending, even if application code has a bug. P3 relies on this.
- **Junction table `guarantors`** with a composite PK resolves the many-to-many between applications and guarantor customers.
- **`loans` is separate from `loan_applications`**: an application can be rejected and never become a loan; the 1:0..1 link is enforced with `UNIQUE(application_id)`.
- **`ledger_entries`** is an append-only record to audit balances against `fund_pool.balance`.
- **Constraints used**: PK, FK, UNIQUE, NOT NULL, CHECK (status enums, positive amounts, age ≥ 18, `outstanding_balance <= principal`), DEFAULT.

## Normalisation
I worked through the stages starting from an unnormalised "loan sheet" like this:

`LoanSheet(customer_name, email, region, product_name, max_amount, loan_amount, installment_1_due, installment_1_amount, installment_2_due, ..., pool_name, pool_balance)`

- **1NF**: remove repeating groups (`installment_1..n`) → separate `repayment_schedule` rows, each field atomic.
- **2NF**: remove partial dependencies. Product details (`max_amount`) depend on the product, not the loan → `loan_products`. Customer attributes → `customers`.
- **3NF**: remove transitive dependencies. `pool_balance` depends on the pool, not the loan → `fund_pool`. No non-key attribute depends on another non-key attribute in the final tables.
- **BCNF check**: in every table the determinants are candidate keys (e.g. in `customers`, `email`, `phone` and `national_id` are each unique and determine the row).
- **Deliberate denormalisation**: `loans.outstanding_balance` is derivable from the schedule, but is kept for fast reads. It is kept consistent through transactions (P3).
  I accepted the duplication on purpose because the balance is read on every screen, and I keep it correct by only changing it inside the transactions in Portfolio 3.
