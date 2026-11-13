-- =====================================================================
-- InterestFree Lend : relational schema (PostgreSQL 16)
-- Portfolio 1 - Database Design and Modelling
-- Business rule: loans carry NO interest. Borrower repays principal only,
-- split into equal instalments. There is no interest or late-fee column.
-- =====================================================================

DROP TABLE IF EXISTS audit_log          CASCADE;
DROP TABLE IF EXISTS ledger_entries     CASCADE;
DROP TABLE IF EXISTS repayments         CASCADE;
DROP TABLE IF EXISTS repayment_schedule CASCADE;
DROP TABLE IF EXISTS loans              CASCADE;
DROP TABLE IF EXISTS guarantors         CASCADE;
DROP TABLE IF EXISTS loan_applications  CASCADE;
DROP TABLE IF EXISTS donations          CASCADE;
DROP TABLE IF EXISTS fund_pool          CASCADE;
DROP TABLE IF EXISTS loan_products      CASCADE;
DROP TABLE IF EXISTS staff              CASCADE;
DROP TABLE IF EXISTS customers          CASCADE;

-- ---------- Customers (borrowers) ----------
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    phone         VARCHAR(20)  NOT NULL UNIQUE,
    national_id   VARCHAR(20)  NOT NULL UNIQUE,
    date_of_birth DATE         NOT NULL,
    region        VARCHAR(20)  NOT NULL
                  CHECK (region IN ('North','South','East','West')),
    kyc_status    VARCHAR(10)  NOT NULL DEFAULT 'PENDING'
                  CHECK (kyc_status IN ('PENDING','VERIFIED','REJECTED')),
    created_at    TIMESTAMP    NOT NULL DEFAULT now(),
    CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '18 years')   -- adults only
);

-- ---------- Staff (loan officers, admins, auditors) ----------
CREATE TABLE staff (
    staff_id  SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email     VARCHAR(120) NOT NULL UNIQUE,
    role      VARCHAR(15)  NOT NULL
              CHECK (role IN ('LOAN_OFFICER','ADMIN','AUDITOR'))
);

-- ---------- Loan products ----------
CREATE TABLE loan_products (
    product_id      SERIAL PRIMARY KEY,
    name            VARCHAR(60)   NOT NULL UNIQUE,
    max_amount      NUMERIC(12,2) NOT NULL CHECK (max_amount > 0),
    max_tenor_months INT          NOT NULL CHECK (max_tenor_months BETWEEN 1 AND 36),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE
);

-- ---------- Fund pool (money donated/pooled that is lent out) ----------
CREATE TABLE fund_pool (
    pool_id SERIAL PRIMARY KEY,
    name    VARCHAR(60)   NOT NULL UNIQUE,
    balance NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0)  -- can never go negative
);

CREATE TABLE donations (
    donation_id SERIAL PRIMARY KEY,
    pool_id     INT           NOT NULL REFERENCES fund_pool(pool_id),
    donor_name  VARCHAR(100)  NOT NULL,
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    donated_at  TIMESTAMP     NOT NULL DEFAULT now()
);

-- ---------- Loan applications ----------
CREATE TABLE loan_applications (
    application_id   SERIAL PRIMARY KEY,
    customer_id      INT           NOT NULL REFERENCES customers(customer_id),
    product_id       INT           NOT NULL REFERENCES loan_products(product_id),
    requested_amount NUMERIC(12,2) NOT NULL CHECK (requested_amount > 0),
    tenor_months     INT           NOT NULL CHECK (tenor_months BETWEEN 1 AND 36),
    purpose          VARCHAR(200),
    status           VARCHAR(10)   NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING','APPROVED','REJECTED','DISBURSED')),
    reviewed_by      INT           REFERENCES staff(staff_id),
    applied_at       TIMESTAMP     NOT NULL DEFAULT now(),
    decided_at       TIMESTAMP,
    CHECK (decided_at IS NULL OR decided_at >= applied_at)
);

-- ---------- Guarantors (a customer can guarantee many applications) ----------
CREATE TABLE guarantors (
    application_id        INT NOT NULL REFERENCES loan_applications(application_id) ON DELETE CASCADE,
    guarantor_customer_id INT NOT NULL REFERENCES customers(customer_id),
    PRIMARY KEY (application_id, guarantor_customer_id)
);

-- ---------- Loans (created at disbursement) ----------
CREATE TABLE loans (
    loan_id             SERIAL PRIMARY KEY,
    application_id      INT           NOT NULL UNIQUE REFERENCES loan_applications(application_id),
    pool_id             INT           NOT NULL REFERENCES fund_pool(pool_id),
    principal           NUMERIC(12,2) NOT NULL CHECK (principal > 0),
    tenor_months        INT           NOT NULL CHECK (tenor_months > 0),
    outstanding_balance NUMERIC(12,2) NOT NULL CHECK (outstanding_balance >= 0),
    status              VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','REPAID','DEFAULTED')),
    disbursed_at        TIMESTAMP     NOT NULL DEFAULT now(),
    CHECK (outstanding_balance <= principal)
);

-- ---------- Repayment schedule (equal instalments of principal) ----------
CREATE TABLE repayment_schedule (
    schedule_id    SERIAL PRIMARY KEY,
    loan_id        INT           NOT NULL REFERENCES loans(loan_id) ON DELETE CASCADE,
    installment_no INT           NOT NULL CHECK (installment_no > 0),
    due_date       DATE          NOT NULL,
    amount_due     NUMERIC(12,2) NOT NULL CHECK (amount_due > 0),
    status         VARCHAR(10)   NOT NULL DEFAULT 'PENDING'
                   CHECK (status IN ('PENDING','PAID')),
    UNIQUE (loan_id, installment_no)
);

-- ---------- Repayments actually received ----------
CREATE TABLE repayments (
    repayment_id SERIAL PRIMARY KEY,
    loan_id      INT           NOT NULL REFERENCES loans(loan_id),
    schedule_id  INT           REFERENCES repayment_schedule(schedule_id),
    amount       NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    method       VARCHAR(10)   NOT NULL DEFAULT 'TRANSFER'
                 CHECK (method IN ('TRANSFER','CARD','CASH','USSD')),
    status       VARCHAR(10)   NOT NULL DEFAULT 'SUCCESS'
                 CHECK (status IN ('SUCCESS','FAILED','REVERSED')),
    paid_at      TIMESTAMP     NOT NULL DEFAULT now()
);

-- ---------- Double-entry style ledger for auditing balances ----------
CREATE TABLE ledger_entries (
    entry_id    BIGSERIAL PRIMARY KEY,
    pool_id     INT           NOT NULL REFERENCES fund_pool(pool_id),
    loan_id     INT           REFERENCES loans(loan_id),
    customer_id INT           REFERENCES customers(customer_id),
    entry_type  VARCHAR(15)   NOT NULL
                CHECK (entry_type IN ('DONATION','DISBURSEMENT','REPAYMENT','REVERSAL')),
    direction   VARCHAR(6)    NOT NULL CHECK (direction IN ('DEBIT','CREDIT')),
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    created_at  TIMESTAMP     NOT NULL DEFAULT now()
);

-- ---------- Audit log of sensitive actions ----------
CREATE TABLE audit_log (
    audit_id   BIGSERIAL PRIMARY KEY,
    staff_id   INT REFERENCES staff(staff_id),
    action     VARCHAR(50) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id  INT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
