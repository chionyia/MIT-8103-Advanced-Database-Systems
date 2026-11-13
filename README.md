# MIT 8103 Advanced Database Systems: Portfolio

**Student:** ONYIA CHIAMAKA (301921857)  ·  **Programme:** MSc/MIT Information Technology  ·  **Session:** 2026/2027, Semester 1

## Selected case study: InterestFree Lend (simulated)
| Item | Description |
|---|---|
| **Organisation / scenario** | *InterestFree Lend*, a simulated fintech platform offering interest-free (Qard Hasan style) loans to individuals and small traders. Funds come from a donor-supported pool; borrowers repay principal only, in equal instalments. |
| **Nature of the system** | Fintech lending platform: onboarding/KYC, loan application and approval, disbursement, repayment tracking, auditing. |
| **Users of the database** | Borrowers (customers), loan officers, administrators, auditors, donors, guarantors. |
| **Major data stored** | Customers and KYC, loan products, applications, guarantors, fund pool and donations, loans, repayment schedules, repayments, ledger entries, audit log. |
| **Key operations** | Apply for loan · approve/reject · disburse (atomic) · record repayment · flag overdue · reverse failed transactions · reconcile fund balance · analyse portfolio risk. |

## Repository map
| Folder | Marks | Contents |
|---|---|---|
| [portfolio-1-database-design](portfolio-1-database-design/) | 7 | ER diagram, schema, constraints, normalisation |
| [portfolio-2-query-optimisation](portfolio-2-query-optimisation/) | 7 | Queries, EXPLAIN plans, indexes, performance analysis |
| [portfolio-3-transactions-concurrency](portfolio-3-transactions-concurrency/) | 7 | COMMIT/ROLLBACK, isolation, lost update, deadlock |
| [portfolio-4-nosql](portfolio-4-nosql/) | 7 | MongoDB, Neo4j, Redis models |
| [portfolio-5-distributed-cloud](portfolio-5-distributed-cloud/) | 6 | Replication, failover, partitioning/sharding, cloud design |
| [docs](docs/) | 6 | Final documentation, reflection, AI-use declaration |

## Quick start
```bash
docker compose up -d postgres
PSQL="docker compose exec -T postgres psql -U ifl -d ifl"
$PSQL < portfolio-1-database-design/schema.sql
$PSQL < portfolio-1-database-design/seed.sql
```
Each portfolio folder has its own README with exact run steps and the evidence produced.
Requirements: Docker + Docker Compose.

## Technology
PostgreSQL 16 · MongoDB 7 · Neo4j 5 · Redis 7 · Docker Compose · Mermaid (diagrams).

## Progress log
Work is committed progressively (see commit history).

## AI use
See [docs/ai-use-declaration.md](docs/ai-use-declaration.md).
