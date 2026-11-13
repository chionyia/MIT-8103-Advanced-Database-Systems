-- Small hand-made dataset used for Portfolio 1 and Portfolio 3 demos.
-- (Portfolio 2 uses a large generated dataset instead.)

INSERT INTO staff (full_name, email, role) VALUES
 ('Amina Bello',  'amina@ifl.example',  'LOAN_OFFICER'),
 ('Chuka Obi',    'chuka@ifl.example',  'ADMIN'),
 ('Ngozi Eze',    'ngozi@ifl.example',  'AUDITOR');

INSERT INTO loan_products (name, max_amount, max_tenor_months) VALUES
 ('Micro Trader Loan', 100000,  6),
 ('Education Support', 300000, 12),
 ('Emergency Relief',   50000,  3);

INSERT INTO fund_pool (name, balance) VALUES
 ('General Fund',   5000000),
 ('Emergency Fund',    1000);     -- deliberately small: used for rollback demo

INSERT INTO donations (pool_id, donor_name, amount) VALUES
 (1, 'Al-Hikma Foundation', 3000000),
 (1, 'Community Members',   2000000),
 (2, 'Anonymous',              1000);

INSERT INTO customers (full_name, email, phone, national_id, date_of_birth, region, kyc_status) VALUES
 ('Tunde Adeyemi',  'tunde@example.com',  '08030000001', 'NIN0000001', '1990-04-12', 'West',  'VERIFIED'),
 ('Fatima Yusuf',   'fatima@example.com', '08030000002', 'NIN0000002', '1988-09-30', 'North', 'VERIFIED'),
 ('Emeka Okafor',   'emeka@example.com',  '08030000003', 'NIN0000003', '1993-01-21', 'East',  'VERIFIED'),
 ('Blessing Udo',   'blessing@example.com','08030000004','NIN0000004', '1995-06-05', 'South', 'VERIFIED'),
 ('Ibrahim Musa',   'ibrahim@example.com','08030000005', 'NIN0000005', '1985-11-17', 'North', 'PENDING');

INSERT INTO loan_applications
 (customer_id, product_id, requested_amount, tenor_months, purpose, status, reviewed_by, applied_at, decided_at) VALUES
 (1, 1, 100000, 6, 'Restock shop',        'APPROVED', 1, now() - interval '3 days', now() - interval '2 days'),
 (2, 1,  50000, 5, 'Buy sewing machine',  'APPROVED', 1, now() - interval '3 days', now() - interval '2 days'),
 (3, 2, 200000,10, 'School fees',         'PENDING',  NULL, now() - interval '1 day', NULL),
 (4, 3,  40000, 3, 'Medical bill',        'REJECTED', 1, now() - interval '5 days', now() - interval '4 days'),
 (1, 3,  50000, 3, 'Emergency relief',    'APPROVED', 1, now() - interval '1 day',  now());

INSERT INTO guarantors VALUES (1, 2), (1, 3), (2, 1), (3, 4), (5, 3);
