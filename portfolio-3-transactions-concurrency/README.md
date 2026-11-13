# Portfolio 3: Transactions and Concurrency

## Files (run in this order)
| File | Demonstrates |
|---|---|
| `01_disburse_function.sql` | Multi-step atomic business transaction (`disburse_loan`) |
| `02_commit_rollback.sql` | COMMIT, automatic ROLLBACK on constraint failure, SAVEPOINT, reconciliation |
| `03_concurrency_lost_update.sql` | Lost update problem, and 3 fixes: `FOR UPDATE`, atomic update, REPEATABLE READ |
| `04_isolation_and_deadlock.sql` | Non-repeatable read, snapshot isolation, deadlock and lock inspection |
| `screenshots/` | One screenshot per demo step (both terminals visible) |

## How to run
```bash
cd portfolio-3-transactions-concurrency
PSQL="docker compose -f ../docker-compose.yml exec -T postgres psql -U ifl -d ifl"
$PSQL < ../portfolio-1-database-design/schema.sql
$PSQL < ../portfolio-1-database-design/seed.sql
$PSQL < 01_disburse_function.sql
$PSQL < 02_commit_rollback.sql | tee test-output-02.txt      # save as evidence
```
For files 03 and 04, open two interactive terminals:
`docker compose -f ../docker-compose.yml exec postgres psql -U ifl -d ifl` and follow the numbered steps.

## ACID in this project
- **Atomicity**: when I tried to disburse a 50,000 loan from the Emergency Fund (only 1,000 in it), the `CHECK (balance >= 0)` constraint failed and everything was rolled back: no loan, no schedule, no ledger row, and the application stayed APPROVED.
- **Consistency**: the CHECK constraints, foreign keys and a reconciliation query (balance = donated - disbursed) keep the money adding up. After my tests, pool 1 showed 5,400,000 = 5,500,000 donated - 100,000 disbursed.
- **Isolation**: the lost update, non-repeatable read and deadlock tests below.
- **Durability**: committed data is written to the write-ahead log (WAL) before the commit returns, so it survives a restart.

## What I found
**Lost update.** Two sessions both read the pool balance (5,000,000), calculated the new balance in their own head, and wrote it back. Session A subtracted 100,000 and Session B subtracted 50,000, but the final balance was 4,950,000 instead of 4,850,000. Session B's write silently overwrote Session A's, so a 100,000 disbursement disappeared from the books. This is the classic read-then-write bug at READ COMMITTED.

**Three ways I fixed it:**
1. `SELECT ... FOR UPDATE` (pessimistic): Session A locks the row, Session B waits, then reads 4,900,000 and subtracts its 50,000. Final balance 4,850,000.
2. A single atomic statement, `SET balance = balance - x`. PostgreSQL re-reads the latest committed value when the lock clears, so both updates apply. Final balance 4,850,000. This is the simplest fix when no application logic is needed between the read and the write.
3. REPEATABLE READ (optimistic): Session B got `could not serialize access due to concurrent update` and had to roll back and retry. Nothing is lost, but the application must handle the retry.

For a lender I would use the atomic update where possible and `FOR UPDATE` when a decision depends on the balance (for example, "only approve if enough funds"). Retries are fine too, but they need retry code.

**Isolation levels.** At READ COMMITTED, one transaction read a loan's repayments total as 0 and then 16,666.67 a few seconds later after another session committed: a non-repeatable read. At REPEATABLE READ the same transaction read 0 both times because it works from a snapshot. PostgreSQL never allows dirty reads, because of MVCC.

**Deadlock.** Two sessions updated pool 1 and pool 2 in opposite orders. PostgreSQL detected the cycle and aborted one session with `deadlock detected`, letting the other finish. To prevent it, always lock rows in the same order and keep transactions short.

## Evidence in this folder
| Evidence | File |
|---|---|
| Commit / rollback / savepoint output | `test-output/test-output-02-commit-rollback.txt` |
| Lost update + 3 fixes output | `test-output/test-output-03-lost-update.txt` |
| Isolation levels + deadlock output | `test-output/test-output-04-isolation-deadlock.txt` |
| Screenshots | `screenshots/` |
| Reproduce everything | `bash run_tests.sh`  |

**Note:** `run_tests.sh` runs the concurrent demos with two parallel `psql` sessions and `pg_sleep` delays. Output lines are grouped per session because each `psql` writes its output when the session ends.
