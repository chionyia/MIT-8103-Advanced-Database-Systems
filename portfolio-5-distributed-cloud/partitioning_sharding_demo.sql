-- Logical sharding demo on ONE node using declarative partitioning by region.
-- This shows the *routing/pruning idea* of sharding. True sharding places partitions on different
-- servers (Citus, or MongoDB sharded cluster). Run after portfolio-2 seed_large.sql.

DROP TABLE IF EXISTS customers_sharded CASCADE;

CREATE TABLE customers_sharded (
    customer_id INT NOT NULL,
    full_name   VARCHAR(100) NOT NULL,
    region      VARCHAR(20)  NOT NULL,
    created_at  TIMESTAMP,
    PRIMARY KEY (customer_id, region)          -- partition key must be in the PK
) PARTITION BY LIST (region);

CREATE TABLE customers_north PARTITION OF customers_sharded FOR VALUES IN ('North');
CREATE TABLE customers_south PARTITION OF customers_sharded FOR VALUES IN ('South');
CREATE TABLE customers_east  PARTITION OF customers_sharded FOR VALUES IN ('East');
CREATE TABLE customers_west  PARTITION OF customers_sharded FOR VALUES IN ('West');

INSERT INTO customers_sharded SELECT customer_id, full_name, region, created_at FROM customers;
ANALYZE customers_sharded;

-- Rows per partition (check the distribution is even)
SELECT tableoid::regclass AS partition, count(*) FROM customers_sharded GROUP BY 1 ORDER BY 1;

-- Partition pruning: only customers_north is scanned
EXPLAIN (ANALYZE) SELECT count(*) FROM customers_sharded WHERE region = 'North';

-- No region in the filter: ALL partitions scanned (scatter-gather), the cost of a bad shard key
EXPLAIN (ANALYZE) SELECT * FROM customers_sharded WHERE customer_id = 4242;
