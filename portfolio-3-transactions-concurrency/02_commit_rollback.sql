-- Prerequisite: portfolio-1 schema.sql + seed.sql, then 01_disburse_function.sql
-- Seed: application 1 (100,000) APPROVED, pool 1 balance 5,000,000, pool 2 balance 1,000.

\echo '--- BEFORE ---'
SELECT pool_id, balance FROM fund_pool;
SELECT application_id, status FROM loan_applications WHERE application_id IN (1,2);

-- ===== A. SUCCESSFUL TRANSACTION: COMMIT =====
BEGIN;
SELECT disburse_loan(1, 1) AS new_loan_id;
\echo '--- inside transaction (visible to this session only) ---'
SELECT pool_id, balance FROM fund_pool WHERE pool_id = 1;
COMMIT;

\echo '--- AFTER COMMIT: loan, schedule, ledger exist, pool debited ---'
SELECT pool_id, balance FROM fund_pool WHERE pool_id = 1;
SELECT loan_id, principal, outstanding_balance FROM loans;
SELECT installment_no, due_date, amount_due FROM repayment_schedule ORDER BY installment_no;
SELECT entry_type, direction, amount FROM ledger_entries;

-- ===== B. FAILING TRANSACTION: automatic ROLLBACK =====
-- Pool 2 only holds 1,000 so debiting 50,000 violates CHECK (balance >= 0).
BEGIN;
SELECT disburse_loan(2, 2);          -- expected: ERROR  fund_pool_balance_check
ROLLBACK;                            -- transaction is aborted anyway

\echo '--- AFTER ROLLBACK: nothing changed for application 2 / pool 2 ---'
SELECT pool_id, balance FROM fund_pool WHERE pool_id = 2;
SELECT application_id, status FROM loan_applications WHERE application_id = 2;   -- still APPROVED
SELECT count(*) AS loans_for_app2 FROM loans WHERE application_id = 2;           -- 0

-- ===== C. MANUAL ROLLBACK + SAVEPOINT =====
BEGIN;
UPDATE fund_pool SET balance = balance + 500000 WHERE pool_id = 1;          -- e.g. donation
INSERT INTO donations (pool_id, donor_name, amount) VALUES (1, 'New Donor', 500000);
SAVEPOINT after_donation;
UPDATE fund_pool SET balance = 0 WHERE pool_id = 1;                         -- operator mistake!
ROLLBACK TO SAVEPOINT after_donation;                                       -- undo only the mistake
COMMIT;
SELECT pool_id, balance FROM fund_pool WHERE pool_id = 1;

-- ===== D. Reconciliation (audit) after all of the above =====
SELECT p.pool_id, p.balance,
       (SELECT COALESCE(SUM(amount),0) FROM donations d WHERE d.pool_id = p.pool_id) AS donated,
       (SELECT COALESCE(SUM(amount),0) FROM ledger_entries e
         WHERE e.pool_id = p.pool_id AND e.direction = 'DEBIT') AS disbursed
FROM fund_pool p;
