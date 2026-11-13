-- Two terminals again ([A] and [B]). Requires a loan to exist (run 02_commit_rollback.sql first, loan_id = 1).

-- ################ PART 1: NON-REPEATABLE READ at READ COMMITTED ################
-- Step 1  [A]  BEGIN ISOLATION LEVEL READ COMMITTED;
-- Step 2  [A]  SELECT COALESCE(SUM(amount),0) FROM repayments WHERE loan_id = 1;        -- 0
-- Step 3  [B]  INSERT INTO repayments (loan_id, schedule_id, amount) VALUES (1, 1, 16666.67);   -- autocommit
-- Step 4  [A]  SELECT COALESCE(SUM(amount),0) FROM repayments WHERE loan_id = 1;        -- 16666.67  (changed mid-transaction!)
-- Step 5  [A]  COMMIT;

-- ################ PART 2: SAME SCENARIO AT REPEATABLE READ ################
-- Cleanup: DELETE FROM repayments WHERE loan_id = 1;
-- Step 1  [A]  BEGIN ISOLATION LEVEL REPEATABLE READ;
-- Step 2  [A]  SELECT COALESCE(SUM(amount),0) FROM repayments WHERE loan_id = 1;        -- 0
-- Step 3  [B]  INSERT INTO repayments (loan_id, schedule_id, amount) VALUES (1, 1, 16666.67);
-- Step 4  [A]  SELECT COALESCE(SUM(amount),0) FROM repayments WHERE loan_id = 1;        -- still 0 (snapshot)
-- Step 5  [A]  COMMIT;                                                                  -- now sees 16666.67
-- Note: PostgreSQL never allows dirty reads, even if you ask for READ UNCOMMITTED. Explain why (MVCC).

-- ################ PART 3: DEADLOCK ################
-- Step 1  [A]  BEGIN;  UPDATE fund_pool SET balance = balance + 1 WHERE pool_id = 1;
-- Step 2  [B]  BEGIN;  UPDATE fund_pool SET balance = balance + 1 WHERE pool_id = 2;
-- Step 3  [A]  UPDATE fund_pool SET balance = balance + 1 WHERE pool_id = 2;   -- waits for B
-- Step 4  [B]  UPDATE fund_pool SET balance = balance + 1 WHERE pool_id = 1;   -- cycle! after ~1s:
--              ERROR: deadlock detected   (Postgres aborts one transaction, the other proceeds)
-- Step 5  both ROLLBACK / COMMIT as appropriate.
-- Prevention: always lock rows in a consistent order (e.g. ORDER BY pool_id), keep transactions short.

-- ################ PART 4: Inspecting locks (run in a third terminal while A is blocked) ################
-- SELECT pid, state, wait_event_type, wait_event, left(query,60) FROM pg_stat_activity WHERE datname = 'ifl';
-- SELECT locktype, relation::regclass, mode, granted FROM pg_locks WHERE relation = 'fund_pool'::regclass;
