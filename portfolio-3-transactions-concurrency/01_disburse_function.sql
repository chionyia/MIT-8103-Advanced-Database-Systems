-- Atomic loan disbursement. Either EVERYTHING happens or NOTHING does.
-- Steps: lock application -> debit fund pool -> create loan -> build schedule -> ledger -> mark application.
CREATE OR REPLACE FUNCTION disburse_loan(p_application_id INT, p_pool_id INT)
RETURNS INT AS $$
DECLARE
    v_app         loan_applications%ROWTYPE;
    v_loan_id     INT;
    v_installment NUMERIC(12,2);
    n             INT;
BEGIN
    SELECT * INTO v_app FROM loan_applications
    WHERE application_id = p_application_id FOR UPDATE;          -- row lock: no double disbursement

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % not found', p_application_id;
    END IF;
    IF v_app.status <> 'APPROVED' THEN
        RAISE EXCEPTION 'Application % is %, only APPROVED can be disbursed', p_application_id, v_app.status;
    END IF;

    -- If the pool is too small, CHECK (balance >= 0) fails and the whole transaction aborts.
    UPDATE fund_pool SET balance = balance - v_app.requested_amount WHERE pool_id = p_pool_id;

    INSERT INTO loans (application_id, pool_id, principal, tenor_months, outstanding_balance)
    VALUES (v_app.application_id, p_pool_id, v_app.requested_amount, v_app.tenor_months, v_app.requested_amount)
    RETURNING loan_id INTO v_loan_id;

    v_installment := round(v_app.requested_amount / v_app.tenor_months, 2);
    FOR n IN 1..v_app.tenor_months LOOP
        INSERT INTO repayment_schedule (loan_id, installment_no, due_date, amount_due)
        VALUES (v_loan_id, n, CURRENT_DATE + n * 30,
                CASE WHEN n = v_app.tenor_months
                     THEN v_app.requested_amount - v_installment * (v_app.tenor_months - 1)  -- absorb rounding
                     ELSE v_installment END);
    END LOOP;

    INSERT INTO ledger_entries (pool_id, loan_id, customer_id, entry_type, direction, amount)
    VALUES (p_pool_id, v_loan_id, v_app.customer_id, 'DISBURSEMENT', 'DEBIT', v_app.requested_amount);

    UPDATE loan_applications SET status = 'DISBURSED' WHERE application_id = p_application_id;

    RETURN v_loan_id;
END;
$$ LANGUAGE plpgsql;
