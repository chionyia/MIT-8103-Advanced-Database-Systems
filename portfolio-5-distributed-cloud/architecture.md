# Proposed cloud architecture: InterestFree Lend

```mermaid
flowchart LR
    App[Mobile / Web App] --> API[API layer]
    API -->|writes + consistent reads| PGP[(PostgreSQL Primary<br/>AZ-1)]
    PGP -. sync WAL .-> PGS[(Standby<br/>AZ-2)]
    PGP -. async WAL .-> PGR[(Read replica<br/>reports)]
    API --> MDB[(MongoDB replica set<br/>applications / KYC)]
    API --> RED[(Redis cache<br/>OTP, reminders)]
    API --> NEO[(Neo4j<br/>guarantor graph)]
    PGR --> BI[Reporting / PAR dashboards]
```

| Component | Consistency need | Replication | Reason |
|---|---|---|---|
| PostgreSQL ledger/loans | Strong | sync standby + async replicas | money correctness |
| MongoDB applications | Tunable (majority writes) | 3-node replica set | availability |
| Redis | Eventual / disposable | optional | speed layer |
| Neo4j | Strong within cluster | causal cluster | risk analysis |
