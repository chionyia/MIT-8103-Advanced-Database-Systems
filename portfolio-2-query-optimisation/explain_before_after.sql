-- Run via the helper in README to capture plans into results/*.txt
-- Step 1: baseline (no extra indexes). Make sure indexes.sql has NOT been run.
\echo '===== PLAN Q8 ====='
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.application_id, a.requested_amount, a.status, l.loan_id, l.outstanding_balance
FROM loan_applications a LEFT JOIN loans l ON l.application_id = a.application_id
WHERE a.customer_id = 4242;

\echo '===== PLAN Q1 ====='
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.full_name, c.phone, l.loan_id, rs.installment_no, rs.due_date, rs.amount_due,
       CURRENT_DATE - rs.due_date AS days_overdue
FROM repayment_schedule rs
JOIN loans l             ON l.loan_id = rs.loan_id
JOIN loan_applications a ON a.application_id = l.application_id
JOIN customers c         ON c.customer_id = a.customer_id
WHERE rs.status = 'PENDING' AND rs.due_date < CURRENT_DATE
ORDER BY days_overdue DESC LIMIT 50;

\echo '===== PLAN Q5 ====='
EXPLAIN (ANALYZE, BUFFERS)
SELECT repayment_id, paid_at::date, amount,
       SUM(amount) OVER (ORDER BY paid_at, repayment_id) AS running_total
FROM repayments WHERE loan_id = 1 AND status = 'SUCCESS' ORDER BY paid_at;
