-- Large synthetic dataset so that index effects are measurable.
-- WARNING: truncates all tables. Run after portfolio-1 schema.sql.
-- ~50k customers, ~60k loans, ~300k schedule rows, ~190k repayments.

TRUNCATE audit_log, ledger_entries, repayments, repayment_schedule, loans,
         guarantors, loan_applications, donations, fund_pool, loan_products,
         staff, customers RESTART IDENTITY CASCADE;

INSERT INTO staff (full_name, email, role) VALUES
 ('Amina Bello','amina@ifl.example','LOAN_OFFICER'),
 ('Chuka Obi','chuka@ifl.example','ADMIN'),
 ('Ngozi Eze','ngozi@ifl.example','AUDITOR');

INSERT INTO loan_products (name, max_amount, max_tenor_months) VALUES
 ('Micro Trader Loan',100000,6),('Education Support',300000,12),('Emergency Relief',50000,3);

INSERT INTO fund_pool (name, balance) VALUES ('General Fund', 900000000);

-- Customers
INSERT INTO customers (full_name, email, phone, national_id, date_of_birth, region, kyc_status)
SELECT 'Customer ' || i,
       'user' || i || '@example.com',
       '080' || lpad(i::text, 8, '0'),
       'NIN' || lpad(i::text, 8, '0'),
       DATE '1960-01-01' + (i % 12000),
       (ARRAY['North','South','East','West'])[1 + i % 4],
       'VERIFIED'
FROM generate_series(1, 50000) AS i;

-- Applications: 80k, three quarters approved
INSERT INTO loan_applications
  (customer_id, product_id, requested_amount, tenor_months, purpose, status, reviewed_by, applied_at, decided_at)
SELECT 1 + (i * 7) % 50000,
       1 + i % 3,
       (ARRAY[20000,30000,50000])[1 + i % 3],
       (ARRAY[6,6,3])[1 + i % 3],
       'Synthetic purpose ' || i,
       CASE WHEN i % 4 = 0 THEN 'REJECTED' ELSE 'DISBURSED' END,
       1,
       now() - make_interval(days => 330 - (i % 300)),
       now() - make_interval(days => 329 - (i % 300))
FROM generate_series(1, 80000) AS i;

-- Loans for every DISBURSED application
INSERT INTO loans (application_id, pool_id, principal, tenor_months, outstanding_balance, status, disbursed_at)
SELECT application_id, 1, requested_amount, tenor_months, requested_amount, 'ACTIVE', decided_at
FROM loan_applications WHERE status = 'DISBURSED';

-- Schedule: equal instalments, every 30 days
INSERT INTO repayment_schedule (loan_id, installment_no, due_date, amount_due, status)
SELECT l.loan_id, n, (l.disbursed_at::date + n * 30), round(l.principal / l.tenor_months, 2), 'PENDING'
FROM loans l, LATERAL generate_series(1, l.tenor_months) AS n;

-- 80% of instalments already due have been paid; the rest are overdue
UPDATE repayment_schedule SET status = 'PAID'
WHERE due_date < CURRENT_DATE AND schedule_id % 5 <> 0;

INSERT INTO repayments (loan_id, schedule_id, amount, method, status, paid_at)
SELECT loan_id, schedule_id, amount_due,
       (ARRAY['TRANSFER','CARD','CASH','USSD'])[1 + schedule_id % 4],
       'SUCCESS', due_date::timestamp
FROM repayment_schedule WHERE status = 'PAID';

-- Keep loans.outstanding_balance consistent with repayments
UPDATE loans l SET outstanding_balance = GREATEST(l.principal - COALESCE(r.paid, 0), 0)
FROM (SELECT loan_id, SUM(amount) AS paid FROM repayments GROUP BY loan_id) r
WHERE r.loan_id = l.loan_id;

UPDATE loans SET status = 'REPAID' WHERE outstanding_balance = 0;

ANALYZE;

SELECT 'customers' t, count(*) FROM customers UNION ALL
SELECT 'applications', count(*) FROM loan_applications UNION ALL
SELECT 'loans', count(*) FROM loans UNION ALL
SELECT 'schedule', count(*) FROM repayment_schedule UNION ALL
SELECT 'repayments', count(*) FROM repayments;
