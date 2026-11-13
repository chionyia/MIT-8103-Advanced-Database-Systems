-- Portfolio 2: business queries for InterestFree Lend
-- Run each with:  EXPLAIN (ANALYZE, BUFFERS) <query>;

-- Q1. Overdue instalments with borrower contact details (JOIN + filter)
SELECT c.full_name, c.phone, l.loan_id, rs.installment_no, rs.due_date, rs.amount_due,
       CURRENT_DATE - rs.due_date AS days_overdue
FROM repayment_schedule rs
JOIN loans l              ON l.loan_id = rs.loan_id
JOIN loan_applications a  ON a.application_id = l.application_id
JOIN customers c          ON c.customer_id = a.customer_id
WHERE rs.status = 'PENDING' AND rs.due_date < CURRENT_DATE
ORDER BY days_overdue DESC
LIMIT 50;

-- Q2. Portfolio-at-risk by region (GROUP BY + HAVING)
SELECT c.region,
       COUNT(DISTINCT l.loan_id)  AS loans_with_arrears,
       SUM(rs.amount_due)         AS amount_overdue
FROM repayment_schedule rs
JOIN loans l             ON l.loan_id = rs.loan_id
JOIN loan_applications a ON a.application_id = l.application_id
JOIN customers c         ON c.customer_id = a.customer_id
WHERE rs.status = 'PENDING' AND rs.due_date < CURRENT_DATE
GROUP BY c.region
HAVING SUM(rs.amount_due) > 0
ORDER BY amount_overdue DESC;

-- Q3. Top 10 borrowers by total amount borrowed (aggregation)
SELECT c.customer_id, c.full_name, COUNT(*) AS loans_taken, SUM(l.principal) AS total_borrowed
FROM customers c
JOIN loan_applications a ON a.customer_id = c.customer_id
JOIN loans l             ON l.application_id = a.application_id
GROUP BY c.customer_id, c.full_name
ORDER BY total_borrowed DESC, c.customer_id
LIMIT 10;

-- Q4. Monthly disbursed vs recovered (CTEs)
WITH disbursed AS (
    SELECT date_trunc('month', disbursed_at) AS month, SUM(principal) AS disbursed
    FROM loans GROUP BY 1
), recovered AS (
    SELECT date_trunc('month', paid_at) AS month, SUM(amount) AS recovered
    FROM repayments WHERE status = 'SUCCESS' GROUP BY 1
)
SELECT COALESCE(d.month, r.month)::date AS month,
       COALESCE(d.disbursed, 0) AS disbursed,
       COALESCE(r.recovered, 0) AS recovered
FROM disbursed d FULL JOIN recovered r ON r.month = d.month
ORDER BY 1;

-- Q5. Running repayment total for one loan (window function)
SELECT repayment_id, paid_at::date, amount,
       SUM(amount) OVER (ORDER BY paid_at, repayment_id) AS running_total
FROM repayments
WHERE loan_id = 1 AND status = 'SUCCESS'
ORDER BY paid_at;

-- Q6. Rank borrowers inside each region by amount borrowed (RANK window)
SELECT * FROM (
    SELECT c.region, c.full_name, SUM(l.principal) AS total_borrowed,
           RANK() OVER (PARTITION BY c.region ORDER BY SUM(l.principal) DESC) AS rnk
    FROM customers c
    JOIN loan_applications a ON a.customer_id = c.customer_id
    JOIN loans l             ON l.application_id = a.application_id
    GROUP BY c.region, c.customer_id, c.full_name
) t
WHERE rnk <= 3
ORDER BY region, rnk;

-- Q7. Customers who never had a loan approved (anti-join with NOT EXISTS)
SELECT c.customer_id, c.full_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM loan_applications a
    WHERE a.customer_id = c.customer_id AND a.status = 'DISBURSED'
)
LIMIT 20;

-- Q8. Point lookup by customer_id through the application/loan chain
SELECT a.application_id, a.requested_amount, a.status, l.loan_id, l.outstanding_balance
FROM loan_applications a
LEFT JOIN loans l ON l.application_id = a.application_id
WHERE a.customer_id = 4242;

-- Q9. Customers in one region (selectivity demo: low-cardinality column)
SELECT COUNT(*) FROM customers WHERE region = 'North' AND kyc_status = 'VERIFIED';
