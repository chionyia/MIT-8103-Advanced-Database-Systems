-- Indexes added AFTER capturing the baseline plans (see explain_before_after.sql).
-- PostgreSQL does NOT automatically index foreign-key columns; these joins need them.

-- Q1/Q2: partial index only on unpaid instalments, ordered for the overdue filter
CREATE INDEX idx_schedule_pending_due ON repayment_schedule (due_date) WHERE status = 'PENDING';

-- Q1/Q2/Q5: FK join columns
CREATE INDEX idx_schedule_loan      ON repayment_schedule (loan_id);
CREATE INDEX idx_repayments_loan    ON repayments (loan_id, paid_at);
-- (loans.application_id is already indexed by its UNIQUE constraint)

-- Q8: application lookup by customer
CREATE INDEX idx_applications_customer ON loan_applications (customer_id);

ANALYZE;
