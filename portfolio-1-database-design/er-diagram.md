# ER Diagram: InterestFree Lend

Mermaid source (renders on GitHub). Export a PNG/SVG of this into `screenshots/er-diagram.png`
(e.g. paste into https://mermaid.live) so it can also be embedded in the LMS document.

```mermaid
erDiagram
    CUSTOMERS ||--o{ LOAN_APPLICATIONS : submits
    LOAN_PRODUCTS ||--o{ LOAN_APPLICATIONS : "applied under"
    STAFF ||--o{ LOAN_APPLICATIONS : reviews
    LOAN_APPLICATIONS ||--o{ GUARANTORS : "backed by"
    CUSTOMERS ||--o{ GUARANTORS : "acts as"
    LOAN_APPLICATIONS ||--o| LOANS : "becomes"
    FUND_POOL ||--o{ LOANS : funds
    FUND_POOL ||--o{ DONATIONS : receives
    LOANS ||--|{ REPAYMENT_SCHEDULE : "has instalments"
    LOANS ||--o{ REPAYMENTS : receives
    REPAYMENT_SCHEDULE ||--o| REPAYMENTS : "settled by"
    FUND_POOL ||--o{ LEDGER_ENTRIES : records
    LOANS ||--o{ LEDGER_ENTRIES : "affects"
    STAFF ||--o{ AUDIT_LOG : performs

    CUSTOMERS {
        int customer_id PK
        string full_name
        string email UK
        string phone UK
        string national_id UK
        date date_of_birth
        string region
        string kyc_status
    }
    LOAN_PRODUCTS {
        int product_id PK
        string name UK
        numeric max_amount
        int max_tenor_months
    }
    LOAN_APPLICATIONS {
        int application_id PK
        int customer_id FK
        int product_id FK
        int reviewed_by FK
        numeric requested_amount
        int tenor_months
        string status
    }
    GUARANTORS {
        int application_id PK,FK
        int guarantor_customer_id PK,FK
    }
    LOANS {
        int loan_id PK
        int application_id FK,UK
        int pool_id FK
        numeric principal
        numeric outstanding_balance
        string status
    }
    REPAYMENT_SCHEDULE {
        int schedule_id PK
        int loan_id FK
        int installment_no
        date due_date
        numeric amount_due
        string status
    }
    REPAYMENTS {
        int repayment_id PK
        int loan_id FK
        int schedule_id FK
        numeric amount
        string status
    }
    FUND_POOL {
        int pool_id PK
        string name UK
        numeric balance
    }
    DONATIONS {
        int donation_id PK
        int pool_id FK
        numeric amount
    }
    LEDGER_ENTRIES {
        bigint entry_id PK
        int pool_id FK
        int loan_id FK
        string entry_type
        string direction
        numeric amount
    }
    STAFF {
        int staff_id PK
        string role
    }
    AUDIT_LOG {
        bigint audit_id PK
        int staff_id FK
        string action
    }
```

## Relationship notes
- **Customer ↔ Application:** one-to-many.
- **Application ↔ Guarantor ↔ Customer:** many-to-many resolved by the `guarantors` junction table (composite PK).
- **Application → Loan:** one-to-zero-or-one (`loans.application_id` is UNIQUE); a loan exists only after disbursement.
- **Loan → Schedule:** one-to-many; `(loan_id, installment_no)` is UNIQUE.
