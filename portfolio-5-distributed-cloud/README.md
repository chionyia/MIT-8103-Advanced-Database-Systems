# Portfolio 5: Distributed and Cloud Database Exercise

Case study: **InterestFree Lend**. Customers across four regions need an always-available loan platform with money-safe data.

## Hands-on setups
| Setup | Demonstrates | Files |
|---|---|---|
| PostgreSQL primary + streaming replica | Replication, read scaling, read-only replica, replication lag | `postgres-replica/` |
| MongoDB 3-node replica set | Automatic failover, availability | `mongo-replica/` |
| Declarative partitioning by region | Sharding idea: shard key choice, pruning vs scatter-gather | `partitioning_sharding_demo.sql` |

### 1. PostgreSQL streaming replication
```bash
cd postgres-replica && docker compose up -d && sleep 10
# on primary: create data
docker exec -it ifl-pg-primary psql -U ifl -d ifl -c "CREATE TABLE t(id int); INSERT INTO t VALUES (1),(2);"
# on replica: data appears (screenshot)
docker exec -it ifl-pg-replica psql -U ifl -d ifl -c "SELECT * FROM t;"
# writes on replica are rejected (screenshot)
docker exec -it ifl-pg-replica psql -U ifl -d ifl -c "INSERT INTO t VALUES (3);"   # ERROR: read-only transaction
# replication status on primary (screenshot)
docker exec -it ifl-pg-primary psql -U ifl -d ifl -c "SELECT client_addr, state, sent_lsn, replay_lsn FROM pg_stat_replication;"
docker exec -it ifl-pg-replica psql -U ifl -d ifl -c "SELECT pg_is_in_recovery();"
```
Failure test: `docker stop ifl-pg-primary`, replica still serves reads. Discuss why *promotion*
(`SELECT pg_promote();`) is a manual/orchestrated step here (production: Patroni, RDS Multi-AZ).

### 2. MongoDB replica set failover
```bash
cd mongo-replica && docker compose up -d && sleep 5
docker exec -i ifl-mongo1 mongosh < init-replica.js
docker exec -it ifl-mongo1 mongosh --eval "rs.status().members.map(m => [m.name, m.stateStr])"   # screenshot
docker stop ifl-mongo1                                                                            # kill the primary
sleep 15
docker exec -it ifl-mongo2 mongosh --eval "rs.status().members.map(m => [m.name, m.stateStr])"   # new PRIMARY elected (screenshot)
docker start ifl-mongo1                                                                           # rejoins as SECONDARY
```

### 3. Partitioning / sharding demo
```bash
docker compose -f ../docker-compose.yml exec -T postgres psql -U ifl -d ifl < partitioning_sharding_demo.sql | tee partitioning-output.txt
```
(Requires the Portfolio 2 large dataset to be loaded.)

## Results
**PostgreSQL replication.** After the primary and replica started, rows inserted on the primary appeared on the replica. An INSERT on the replica failed with `cannot execute INSERT in a read-only transaction`. On the primary, `pg_stat_replication` showed `state = streaming` with `sent_lsn` and `replay_lsn` both at `0/30587D8`, meaning the replica had replayed everything sent, and the replica reported `pg_is_in_recovery = t`. Screenshots: `screenshots/01` to `03`, `pg-replica-readonly-error.png`, `pg-replication-status.png`.

**MongoDB failover.** With the three-node replica set running (mongo1 primary, priority 2), a document was written with `w: "majority"` and then mongo1 was stopped. Within about 15 seconds mongo2 was elected PRIMARY, the document was still readable, and when mongo1 came back it rejoined and took the primary role again because of its higher priority.

**Partitioning (single-node stand-in for sharding).** Partitioning customers by region gave four partitions of 12,500 rows each. A query filtered on `region = 'North'` scanned only `customers_north`. A query by `customer_id` alone had to check all four partitions, because the partition key was not in the filter.

## Discussion
**Replication.** Streaming replication ships the write-ahead log from the primary to the replica. It gives me a second copy for failure and a place to run reports without slowing down loan processing. Asynchronous replication is faster but a failover can lose the last few commits. Synchronous replication loses nothing but makes every commit wait for the replica. For this platform I would use synchronous replication for the ledger and fund pool, where losing a disbursement is unacceptable, and asynchronous replicas for reporting.

**Sharding.** The partitioning demo shows the idea. If I shard by `region`, regional queries hit one shard and data can stay close to the customers, but a busy region becomes a hot shard. If I hash `customer_id`, load spreads evenly but region reports have to ask every shard. I would pick `customer_id` for the loan data because most operations are per customer. The demo also shows the cost of a poor key: the `customer_id` query touched all four partitions. A transaction that touches two shards (a pool on one, a borrower on another) would need two-phase commit or a saga, which is one more reason to keep the fund pool and ledger on a single primary.

**CAP and consistency.** Money movement needs consistency, so I choose a single writable primary for disbursements and repayments and accept that it is briefly unavailable during failover. Application documents, reminders and dashboards can be eventually consistent. MongoDB with majority write concern is what protected the document during the failover test.

**Availability.** Replicas in a second availability zone plus automated failover give a short recovery time. Backups with point-in-time recovery cover mistakes like a bad delete that replication would copy to every node.

**Cloud deployment.** `architecture.md` has the design: managed PostgreSQL with Multi-AZ and a read replica, a managed MongoDB replica set, managed Redis, and Neo4j for the graph, in private subnets with encryption at rest and in transit because KYC data is sensitive.
