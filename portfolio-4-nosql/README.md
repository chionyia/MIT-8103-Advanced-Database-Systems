# Portfolio 4: NoSQL and Advanced Data Models

Same case study (InterestFree Lend). Three NoSQL models, each chosen because it fits a specific problem the relational model handles poorly.

| Model | Tool | Use case in the case study | Files |
|---|---|---|---|
| **Document** | MongoDB 7 | Loan applications with variable KYC and product-specific data | `mongo_loan_applications.js` |
| **Graph** | Neo4j 5 | Guarantor/referral network, multi-hop default exposure | `neo4j_guarantor_graph.cypher` |
| **Key-value** | Redis 7 | Reminders, OTPs, loan summary cache, rate limiting | `redis_commands.txt` |

## How to run
```bash
docker compose up -d mongo neo4j redis             # from repo root
docker compose exec -T mongo mongosh < portfolio-4-nosql/mongo_loan_applications.js | tee portfolio-4-nosql/mongo-output.txt
docker compose exec -T neo4j cypher-shell -u neo4j -p ifl_pass_123 < portfolio-4-nosql/neo4j_guarantor_graph.cypher | tee portfolio-4-nosql/neo4j-output.txt
docker compose exec redis redis-cli      # then paste the commands from redis_commands.txt
```
(Neo4j needs about 30 s to start. The graph can be viewed in Neo4j Browser at http://localhost:7474.)

## Why each model fits
**Document (MongoDB).** Loan applications are not all the same shape. An education loan carries an admission letter and fees due, while a trader loan carries business type and monthly revenue. In SQL that means lots of NULL columns or extra tables. In Mongo each application is one document with its KYC details, guarantors and status history embedded, so one read returns everything the officer needs and I do not join five tables. Updating the status and appending to the history is a single-document update, which is atomic. I did not move money here on purpose: anything that changes balances needs multi-table ACID transactions, so the ledger, fund pool and repayments stay in PostgreSQL. The Mongo explain on 4 documents examined 1 document, which only shows the index was used. A real comparison needs far more data.

**Graph (Neo4j).** Questions like "who is exposed if this borrower defaults?" or "do two customers guarantee each other?" are about relationships across several hops. In the graph they are short patterns. In SQL they would be self-joins or recursive queries on the guarantors table. The queries found that Tunde guarantees a defaulted loan (L2) and that Tunde and Fatima guarantee each other's loans, which is the kind of ring a lender would want to look at.

**Key-value (Redis).** OTPs, repayment reminders and rate limits are small, short-lived and read constantly, so Redis keys with a TTL fit well (`SET otp:... EX 300`). It is a speed layer, not a system of record. One thing to watch: `HINCRBYFLOAT` returns `66666.65999999999999659` instead of `66666.66`, a floating-point artefact. That is a good reason not to keep money balances in Redis. Money stays in PostgreSQL `NUMERIC`.

## How they fit together (polyglot persistence)
PostgreSQL is the system of record for money and uses full ACID. MongoDB holds the flexible application and KYC documents. Neo4j holds the guarantor network for risk analysis. Redis is the fast cache in front of them.

| Concern | PostgreSQL | MongoDB | Neo4j | Redis |
|---|---|---|---|---|
| Schema | Strict, enforced | Flexible per document | Flexible | None |
| Transactions | Full ACID across tables | Atomic per document | ACID | Limited |
| Best at | Joins, aggregates, money | Fetching a whole application | Multi-hop relationships | Key lookups, TTL, counters |
| Used for | Loans, ledger, repayments | Applications and KYC | Guarantor and referral network | OTPs, reminders, rate limits |
