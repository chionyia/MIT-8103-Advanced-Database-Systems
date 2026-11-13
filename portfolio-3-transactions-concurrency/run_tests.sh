#!/usr/bin/env bash
# Reproducible test run for Portfolio 3. Writes evidence to test-output/*.txt
# The two-session demos are scripted with two parallel psql sessions and pg_sleep delays
# (same steps as 03_*.sql and 04_*.sql). Run from this folder:  bash run_tests.sh
set -u
cd "$(dirname "$0")"
DC="docker compose -f ../docker-compose.yml"
PSQL="$DC exec -T postgres psql -U ifl -d ifl"
Q="$PSQL -q -t -A"
OUT=test-output; mkdir -p $OUT
# psql output of each session is flushed when the session ends, so lines from A and B can interleave
# out of step order. group() lists each session's lines together (A first, then B) for readability.
group(){ python3 -c "
import sys
buf=[]
def flush():
    global buf
    for t in ('[A]','[B]'): [print(l,end='') for l in buf if l.startswith(t)]
    buf=[]
for l in sys.stdin:
    if l.startswith('[A]') or l.startswith('[B]'): buf.append(l)
    else: flush(); print(l,end='')
flush()"; }

$DC up -d postgres >/dev/null 2>&1
until $DC exec -T postgres pg_isready -U ifl >/dev/null 2>&1; do sleep 1; done
sleep 2
fresh(){ $PSQL < ../portfolio-1-database-design/schema.sql >/dev/null 2>&1
         $PSQL < ../portfolio-1-database-design/seed.sql   >/dev/null 2>&1
         $PSQL < 01_disburse_function.sql >/dev/null 2>&1; }

# ---------- 02: commit / rollback ----------
fresh
{ echo "### test-output 02: COMMIT, ROLLBACK, SAVEPOINT  ($(date -u +%F\ %T) UTC, PostgreSQL 16)"
  $PSQL < 02_commit_rollback.sql 2>&1; } > $OUT/test-output-02-commit-rollback.txt

# ---------- 03: lost update + fixes ----------
reset(){ $Q -c "UPDATE fund_pool SET balance=5000000 WHERE pool_id=1"; }
{
echo "### test-output 03: lost update and fixes  ($(date -u +%F\ %T) UTC)"
echo; echo "=== PART 1: THE PROBLEM (read-then-write)  expected final = 4850000 ==="; reset
( $Q <<'EOF' | sed 's/^/[A] /'
BEGIN;
SELECT 'read balance', balance FROM fund_pool WHERE pool_id=1;
SELECT pg_sleep(3);
UPDATE fund_pool SET balance = 5000000 - 100000 WHERE pool_id=1;
COMMIT;
EOF
) &
( sleep 1; $Q <<'EOF' | sed 's/^/[B] /'
BEGIN;
SELECT 'read balance', balance FROM fund_pool WHERE pool_id=1;
SELECT pg_sleep(4);
UPDATE fund_pool SET balance = 5000000 - 50000 WHERE pool_id=1;
COMMIT;
EOF
) &
wait; echo "FINAL balance: $($Q -c 'SELECT balance FROM fund_pool WHERE pool_id=1')   <-- LOST UPDATE (A's 100000 vanished)"

echo; echo "=== PART 2: FIX 1, SELECT ... FOR UPDATE ==="; reset
( $Q <<'EOF' | sed 's/^/[A] /'
BEGIN;
SELECT 'read (locks row)', balance FROM fund_pool WHERE pool_id=1 FOR UPDATE;
SELECT pg_sleep(3);
UPDATE fund_pool SET balance = balance - 100000 WHERE pool_id=1;
COMMIT;
EOF
) &
( sleep 1; $Q <<'EOF' | sed 's/^/[B] /'
BEGIN;
SELECT 'read (waited for A)', balance FROM fund_pool WHERE pool_id=1 FOR UPDATE;
UPDATE fund_pool SET balance = balance - 50000 WHERE pool_id=1;
COMMIT;
EOF
) &
wait; echo "FINAL balance: $($Q -c 'SELECT balance FROM fund_pool WHERE pool_id=1')   <-- correct"

echo; echo "=== PART 3: FIX 2, atomic update (no read) ==="; reset
( $Q -c "BEGIN; UPDATE fund_pool SET balance=balance-100000 WHERE pool_id=1; SELECT pg_sleep(3); COMMIT;" >/dev/null ) &
( sleep 1; $Q -c "UPDATE fund_pool SET balance=balance-50000 WHERE pool_id=1" >/dev/null ) &
wait; echo "FINAL balance: $($Q -c 'SELECT balance FROM fund_pool WHERE pool_id=1')   <-- correct"

echo; echo "=== PART 4: FIX 3, REPEATABLE READ detects the conflict ==="; reset
( $Q <<'EOF' 2>&1 | grep -v '^$' | sed 's/^/[A] /'
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT 'A snapshot', balance FROM fund_pool WHERE pool_id=1;
SELECT pg_sleep(2);
UPDATE fund_pool SET balance = balance - 100000 WHERE pool_id=1;
COMMIT;
EOF
) &
( sleep 1; $Q <<'EOF' 2>&1 | grep -v '^$' | sed 's/^/[B] /'
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT 'B snapshot', balance FROM fund_pool WHERE pool_id=1;
SELECT pg_sleep(2);
UPDATE fund_pool SET balance = balance - 50000 WHERE pool_id=1;
COMMIT;
EOF
) &
wait; echo "FINAL balance: $($Q -c 'SELECT balance FROM fund_pool WHERE pool_id=1')   <-- B aborted, must retry"
} 2>&1 | group > $OUT/test-output-03-lost-update.txt

# ---------- 04: isolation + deadlock (needs loan 1 from the commit demo) ----------
{
echo "### test-output 04: isolation levels and deadlock  ($(date -u +%F\ %T) UTC)"
for LVL in "READ COMMITTED" "REPEATABLE READ"; do
  echo; echo "=== $LVL ==="; $Q -c "DELETE FROM repayments WHERE loan_id=1"
  ( $Q <<EOF | grep -v '^$' | sed 's/^/[A] /'
BEGIN ISOLATION LEVEL $LVL;
SELECT 'first read ', COALESCE(SUM(amount),0) FROM repayments WHERE loan_id=1;
SELECT pg_sleep(3);
SELECT 'second read', COALESCE(SUM(amount),0) FROM repayments WHERE loan_id=1;
COMMIT;
EOF
  ) &
  ( sleep 1; $Q -c "INSERT INTO repayments (loan_id, schedule_id, amount) VALUES (1,1,16666.67)" >/dev/null; echo "[B] inserted and committed a 16666.67 repayment") &
  wait
done
echo; echo "=== DEADLOCK (opposite lock order) ==="
( $Q <<'EOF' 2>&1 | grep -v '^$' | sed 's/^/[A] /'
BEGIN;
UPDATE fund_pool SET balance = balance + 1 WHERE pool_id=1;
SELECT pg_sleep(2);
UPDATE fund_pool SET balance = balance + 1 WHERE pool_id=2;
COMMIT;
EOF
) &
( sleep 0.5; $Q <<'EOF' 2>&1 | grep -v '^$' | sed 's/^/[B] /'
BEGIN;
UPDATE fund_pool SET balance = balance + 1 WHERE pool_id=2;
SELECT pg_sleep(2);
UPDATE fund_pool SET balance = balance + 1 WHERE pool_id=1;
COMMIT;
EOF
) &
wait
echo "(one session was aborted by the deadlock detector, the other committed)"
} 2>&1 | group > $OUT/test-output-04-isolation-deadlock.txt

echo "Done. Evidence in $(pwd)/$OUT/"
