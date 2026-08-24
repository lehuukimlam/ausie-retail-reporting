-- Small OLTP seed for ausie_retail_oltp. Run AFTER mysql/ddl.sql.
-- Duplicate POS retries are not in this file (unique source_event_id).

USE ausie_retail_oltp;

INSERT INTO store (
    store_id, store_code, store_name, channel, timezone_name,
    address_line_1, address_line_2, suburb, state_text, postcode_text,
    country_code, phone, is_active
) VALUES
(1, 'SYD01', 'Harbour & Home Sydney', 'offline', 'Australia/Sydney', '118 George Street', NULL, 'Sydney', 'NSW', '2000', 'AU', '02 9123 4101', 1),
(2, 'MEL01', 'Harbour & Home Melbourne', 'offline', 'Australia/Melbourne', '245 Collins Street', NULL, 'Melbourne', 'VIC', '3000', 'AU', '03 9123 4201', 1),
(3, 'BNE01', 'Harbour & Home Brisbane', 'offline', 'Australia/Brisbane', '76 Queen Street', NULL, 'Brisbane City', 'QLD', '4000', 'AU', '07 3123 4301', 1),
(4, 'PER01', 'Harbour & Home Perth', 'offline', 'Australia/Perth', '140 Murray Street', NULL, 'Perth', 'WA', '6000', 'AU', '08 6123 4401', 1),
(5, 'ADL01', 'Harbour & Home Adelaide', 'offline', 'Australia/Adelaide', '91 Rundle Mall', NULL, 'Adelaide', 'SA', '5000', 'AU', '08 8123 4501', 1),
(6, 'ONLINE', 'Harbour & Home Online', 'online', 'Australia/Sydney', NULL, NULL, 'Sydney', 'NSW', '2000', 'AU', NULL, 1);

INSERT INTO staff (
    staff_version_id, staff_id, staff_number, store_id,
    first_name, last_name, email, role_name, state_text,
    effective_from, effective_to, is_current
) VALUES
(501, 1, 'STF0001', 1, 'Emma', 'Reid', 'emma.reid@harbourhome.example', 'Sales Assistant', 'NSW', '2024-01-01 00:00:00', '2025-02-01 00:00:00', 0),
(502, 1, 'STF0001', 2, 'Emma', 'Reid', 'emma.reid@harbourhome.example', 'Assistant Manager', 'VIC', '2025-02-01 00:00:00', NULL, 1),
(503, 2, 'STF0002', 2, 'Liam', 'Chen', 'liam.chen@harbourhome.example', 'Sales Assistant', 'VIC', '2024-01-01 00:00:00', NULL, 1),
(504, 3, 'STF0003', 3, 'Olivia', 'Patel', 'olivia.patel@harbourhome.example', 'Store Manager', 'QLD', '2024-01-01 00:00:00', NULL, 1),
(505, 4, 'STF0004', 4, 'Noah', 'Williams', 'noah.williams@harbourhome.example', 'Sales Assistant', 'WA', '2024-01-01 00:00:00', NULL, 1),
(506, 5, 'STF0005', 5, 'Ava', 'Brown', 'ava.brown@harbourhome.example', 'Store Manager', 'SA', '2024-01-01 00:00:00', NULL, 1),
(507, 6, 'STF0006', 1, 'Jack', 'Wilson', 'jack.wilson@harbourhome.example', 'Sales Assistant', 'NSW', '2024-01-01 00:00:00', NULL, 1),
(508, 7, 'STF0007', 3, 'Mia', 'Taylor', 'mia.taylor@harbourhome.example', 'Sales Assistant', 'QLD', '2024-01-01 00:00:00', NULL, 1),
(509, 8, 'STF0008', 6, 'Ethan', 'Nguyen', 'ethan.nguyen@harbourhome.example', 'Online Operations', 'NSW', '2024-01-01 00:00:00', NULL, 1);

INSERT INTO product (
    product_version_id, product_id, sku, product_name,
    category_name, brand_name, unit_of_measure,
    unit_cost_ex_gst, unit_price_ex_gst, gst_rate,
    is_active, effective_from, effective_to, is_current
) VALUES
(1001, 1, 'CND-COASTAL', 'Coastal Soy Candle 300g', 'Home Fragrance', 'Southern Light', 'EA', 15.00, 30.00, 0.100000, 1, '2024-01-01 00:00:00', '2025-03-01 00:00:00', 0),
(1002, 1, 'CND-COASTAL', 'Coastal Soy Candle 320g', 'Home Fragrance', 'Southern Light', 'EA', 16.00, 32.00, 0.100000, 1, '2025-03-01 00:00:00', NULL, 1),
(1003, 2, 'DIF-EUCALYPTUS', 'Eucalyptus Reed Diffuser', 'Home Fragrance', 'Southern Light', 'EA', 20.00, 40.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1004, 3, 'SOAP-LEMONMYRTLE', 'Lemon Myrtle Soap Bar', 'Bath & Body', 'Bush Botanics', 'EA', 4.50, 10.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1005, 4, 'CRM-MACADAMIA', 'Macadamia Hand Cream', 'Bath & Body', 'Bush Botanics', 'EA', 9.00, 20.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1006, 5, 'TEA-BUSHBLEND', 'Australian Bush Tea Blend', 'Pantry', 'Ranges Pantry', 'EA', 7.00, 15.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1007, 6, 'MUG-STONEWARE', 'Coastal Stoneware Mug', 'Homewares', 'Clay & Coast', 'EA', 8.00, 18.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1008, 7, 'TOTE-CANVAS', 'Native Flora Canvas Tote', 'Accessories', 'Wild Coast', 'EA', 11.00, 25.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1009, 8, 'JNL-KRAFT', 'Australian Flora Journal', 'Stationery', 'Paper Gum', 'EA', 9.50, 22.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1010, 9, 'SCF-MERINO', 'Merino Wool Scarf', 'Accessories', 'High Country', 'EA', 24.00, 50.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1011, 10, 'EAR-OPALDROP', 'Opal Drop Earrings', 'Jewellery', 'Red Earth Studio', 'EA', 28.00, 60.00, 0.100000, 1, '2024-01-01 00:00:00', '2025-07-01 00:00:00', 0),
(1012, 10, 'EAR-OPALDROP', 'Opal Drop Earrings - Gold Vermeil', 'Jewellery', 'Red Earth Studio', 'EA', 31.00, 65.00, 0.100000, 1, '2025-07-01 00:00:00', NULL, 1),
(1013, 11, 'NEC-OPAL', 'Australian Opal Pendant', 'Jewellery', 'Red Earth Studio', 'EA', 38.00, 80.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1014, 12, 'BWL-CERAMIC', 'Handmade Ceramic Serving Bowl', 'Homewares', 'Clay & Coast', 'EA', 16.00, 35.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1015, 13, 'BLK-MERINO', 'Merino Throw Blanket', 'Homewares', 'High Country', 'EA', 48.00, 100.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1016, 14, 'SCR-SALT', 'Sea Salt Body Scrub', 'Bath & Body', 'Bush Botanics', 'EA', 12.00, 28.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1),
(1017, 15, 'BOX-GIFT', 'Australiana Gift Box', 'Gift Packaging', 'Harbour & Home', 'EA', 5.00, 12.00, 0.100000, 1, '2024-01-01 00:00:00', NULL, 1);

INSERT INTO customer (
    customer_id, customer_number, first_name, last_name,
    email, phone, address_line_1, address_line_2,
    suburb, state_text, postcode_text, country_code
) VALUES
(1, 'CUS0001', 'Alice', 'Smith', 'Alice.Smith@Example.COM', '0412 555 101', '18 Harbour Road', NULL, 'Manly', 'N.S.W.', '2095', 'AU'),
(2, 'CUS0002', 'Daniel', 'Murphy', 'daniel.murphy@example.com', '0413 555 102', '42 Lygon Street', 'Unit 5', 'Carlton', 'VIC', '3053', 'AU'),
(3, 'CUS0003', 'Sophie', 'Lee', 'sophie.lee@example.com', '0414 555 103', '7 River Terrace', NULL, 'South Brisbane', 'QLD', '4101', 'AU'),
(4, 'CUS0004', 'Benjamin', 'Walker', 'BEN.WALKER@example.com', '0415 555 104', '66 Beaufort Street', NULL, 'Perth', 'WA', '6000', 'AU'),
(5, 'CUS0005', 'Chloe', 'Martin', 'chloe.martin@example.com', '0416 555 105', '15 Hutt Street', NULL, 'Adelaide', 'SA', '5000', 'AU'),
(6, 'CUS0006', 'Thomas', 'Evans', 'thomas.evans@example.com', NULL, '9 Crown Street', NULL, 'Wollongong', 'NSW', '2500', 'AU'),
(7, 'CUS0007', 'Grace', 'Kim', 'grace.kim@Example.com', '0418 555 107', '31 Smith Street', 'Apt 8', 'Fitzroy', 'Victoria', '3065', 'AU'),
(8, NULL, 'Henry', 'Jones', 'henry.jones@example.com', '0419 555 108', '4 Boundary Street', NULL, 'West End', 'QLD', '4101', 'AU');

INSERT INTO sales_header (
    sales_header_id, transaction_number, source_system, source_event_id,
    store_id, staff_version_id, customer_id, original_sales_header_id,
    transaction_type, transaction_at, subtotal_inc_gst, discount_inc_gst,
    gst_amount, total_inc_gst, state_text
) VALUES
(1, 'SYD01-20240210-0001', 'POS', 'POS-SYD01-20240210-0001', 1, 501, NULL, NULL, 'SALE', '2024-02-10 11:24:18', 79.20, 0.00, 7.20, 79.20, 'NSW'),
(2, 'MEL01-20240628-0042', 'POS', 'POS-MEL01-20240628-0042', 2, 503, 2, NULL, 'SALE', '2024-06-28 16:42:05', 114.40, 4.40, 10.00, 110.00, 'VIC'),
(3, 'BNE01-20241226-0118', 'POS', 'POS-BNE01-20241226-0118', 3, 504, 3, NULL, 'SALE', '2024-12-26 10:08:44', 165.00, 16.50, 13.50, 148.50, 'QLD'),
(4, 'SYD01-20250115-0031', 'POS', 'POS-SYD01-20250115-0031', 1, 501, 1, NULL, 'SALE', '2025-01-15 14:17:29', 123.20, 0.00, 11.20, 123.20, 'N.S.W.'),
(5, 'MEL01-20250310-0067', 'POS', 'POS-MEL01-20250310-0067', 2, 502, 7, NULL, 'SALE', '2025-03-10 12:35:11', 123.20, 0.00, 11.20, 123.20, 'VIC'),
(6, 'PER01-20250405-0024', 'POS', 'POS-PER01-20250405-0024', 4, 505, 4, NULL, 'SALE', '2025-04-05 15:51:33', 170.50, 5.50, 15.00, 165.00, 'WA'),
(7, 'ADL01-20250629-0091', 'POS', 'POS-ADL01-20250629-0091', 5, 506, 5, NULL, 'SALE', '2025-06-29 13:06:57', 191.40, 11.00, 16.40, 180.40, 'SA'),
(8, 'SYD01-20250712-0075', 'POS', 'POS-SYD01-20250712-0075', 1, 507, 6, NULL, 'SALE', '2025-07-12 17:22:40', 132.00, 0.00, 12.00, 132.00, 'NSW'),
(9, 'BNE01-20250803-0056', 'POS', 'POS-BNE01-20250803-0056', 3, 508, 8, NULL, 'SALE', '2025-08-03 11:47:16', 57.20, 0.00, 5.20, 57.20, 'QLD'),
(10, 'MEL01-20251018-0134', 'POS', 'POS-MEL01-20251018-0134', 2, 502, 2, NULL, 'SALE', '2025-10-18 18:03:51', 73.70, 0.00, 6.70, 73.70, 'VIC'),
(11, 'SYD01-20240214-R001', 'POS', 'POS-SYD01-20240214-R001', 1, 501, NULL, 1, 'RETURN', '2024-02-14 09:33:20', -11.00, 0.00, -1.00, -11.00, 'NSW'),
(12, 'ADL01-20250705-R004', 'POS', 'POS-ADL01-20250705-R004', 5, 506, 5, 7, 'RETURN', '2025-07-05 12:18:04', -30.80, 0.00, -2.80, -30.80, 'SA');

INSERT INTO sales_line (
    sales_line_id, sales_header_id, line_number, product_version_id,
    original_sales_line_id, qty, unit_price_inc_gst,
    discount_inc_gst, gst_amount, line_total_inc_gst
) VALUES
(1, 1, 1, 1001, NULL, 1.000, 33.0000, 0.00, 3.00, 33.00),
(2, 1, 2, 1004, NULL, 2.000, 11.0000, 0.00, 2.00, 22.00),
(3, 1, 3, 1009, NULL, 1.000, 24.2000, 0.00, 2.20, 24.20),
(4, 2, 1, 1003, NULL, 1.000, 44.0000, 4.40, 3.60, 39.60),
(5, 2, 2, 1007, NULL, 2.000, 19.8000, 0.00, 3.60, 39.60),
(6, 2, 3, 1016, NULL, 1.000, 30.8000, 0.00, 2.80, 30.80),
(7, 3, 1, 1010, NULL, 1.000, 55.0000, 5.50, 4.50, 49.50),
(8, 3, 2, 1015, NULL, 1.000, 110.0000, 11.00, 9.00, 99.00),
(9, 4, 1, 1001, NULL, 2.000, 33.0000, 0.00, 6.00, 66.00),
(10, 4, 2, 1006, NULL, 1.000, 16.5000, 0.00, 1.50, 16.50),
(11, 4, 3, 1008, NULL, 1.000, 27.5000, 0.00, 2.50, 27.50),
(12, 4, 4, 1017, NULL, 1.000, 13.2000, 0.00, 1.20, 13.20),
(13, 5, 1, 1002, NULL, 1.000, 35.2000, 0.00, 3.20, 35.20),
(14, 5, 2, 1011, NULL, 1.000, 66.0000, 0.00, 6.00, 66.00),
(15, 5, 3, 1005, NULL, 1.000, 22.0000, 0.00, 2.00, 22.00),
(16, 6, 1, 1003, NULL, 1.000, 44.0000, 0.00, 4.00, 44.00),
(17, 6, 2, 1013, NULL, 1.000, 88.0000, 5.50, 7.50, 82.50),
(18, 6, 3, 1014, NULL, 1.000, 38.5000, 0.00, 3.50, 38.50),
(19, 7, 1, 1015, NULL, 1.000, 110.0000, 11.00, 9.00, 99.00),
(20, 7, 2, 1016, NULL, 2.000, 30.8000, 0.00, 5.60, 61.60),
(21, 7, 3, 1007, NULL, 1.000, 19.8000, 0.00, 1.80, 19.80),
(22, 8, 1, 1012, NULL, 1.000, 71.5000, 0.00, 6.50, 71.50),
(23, 8, 2, 1004, NULL, 3.000, 11.0000, 0.00, 3.00, 33.00),
(24, 8, 3, 1008, NULL, 1.000, 27.5000, 0.00, 2.50, 27.50),
(25, 9, 1, 1006, NULL, 2.000, 16.5000, 0.00, 3.00, 33.00),
(26, 9, 2, 1009, NULL, 1.000, 24.2000, 0.00, 2.20, 24.20),
(27, 10, 1, 1002, NULL, 1.000, 35.2000, 0.00, 3.20, 35.20),
(28, 10, 2, 1014, NULL, 1.000, 38.5000, 0.00, 3.50, 38.50),
(29, 11, 1, 1004, 2, -1.000, 11.0000, 0.00, -1.00, -11.00),
(30, 12, 1, 1016, 20, -1.000, 30.8000, 0.00, -2.80, -30.80);

INSERT INTO online_order_header (
    online_order_header_id, order_number, source_system, source_event_id,
    customer_id, fulfilment_store_id, original_online_order_header_id,
    order_type, order_status, order_at,
    subtotal_inc_gst, discount_inc_gst, shipping_inc_gst,
    gst_amount, total_inc_gst,
    shipping_name, shipping_address_line_1, shipping_address_line_2,
    shipping_suburb, shipping_state_text, shipping_postcode_text,
    shipping_country_code
) VALUES
(1, 'WEB-20240320-0001', 'ECOM', 'ECOM-20240320-0001', 1, 1, NULL, 'SALE', 'shipped', '2024-03-20 20:14:06', 79.20, 0.00, 0.00, 7.20, 79.20, 'Alice Smith', '18 Harbour Road', NULL, 'Manly', 'N.S.W.', '2095', 'AU'),
(2, 'WEB-20241215-0088', 'ECOM', 'ECOM-20241215-0088', 2, 2, NULL, 'SALE', 'shipped', '2024-12-15 21:05:43', 167.20, 2.20, 0.00, 15.00, 165.00, 'Daniel Murphy', '42 Lygon Street', 'Unit 5', 'Carlton', 'VIC', '3053', 'AU'),
(3, 'WEB-20250105-0019', 'ECOM', 'ECOM-20250105-0019', NULL, 3, NULL, 'SALE', 'paid', '2025-01-05 08:44:17', 85.80, 0.00, 0.00, 7.80, 85.80, 'Guest Checkout', '22 James Street', NULL, 'Fortitude Valley', 'QLD', '4006', 'AU'),
(4, 'WEB-20250522-0142', 'ECOM', 'ECOM-20250522-0142', 3, 4, NULL, 'SALE', 'shipped', '2025-05-22 19:27:34', 145.20, 5.50, 0.00, 12.70, 139.70, 'Sophie Lee', '7 River Terrace', NULL, 'South Brisbane', 'QLD', '4101', 'AU'),
(5, 'WEB-20250825-0204', 'ECOM', 'ECOM-20250825-0204', 4, 5, NULL, 'SALE', 'paid', '2025-08-25 22:11:09', 133.10, 0.00, 0.00, 12.10, 133.10, 'Benjamin Walker', '66 Beaufort Street', NULL, 'Perth', 'WA', '6000', 'AU'),
(6, 'WEB-20250902-R001', 'ECOM', 'ECOM-20250902-R001', 1, 1, 1, 'RETURN', 'refunded', '2025-09-02 10:38:25', -57.20, 0.00, 0.00, -5.20, -57.20, 'Alice Smith', '18 Harbour Road', NULL, 'Manly', 'N.S.W.', '2095', 'AU');

INSERT INTO online_order_line (
    online_order_line_id, online_order_header_id, line_number,
    product_version_id, original_online_order_line_id,
    qty, unit_price_inc_gst, discount_inc_gst,
    gst_amount, line_total_inc_gst
) VALUES
(101, 1, 1, 1003, NULL, 1.000, 44.0000, 0.00, 4.00, 44.00),
(102, 1, 2, 1004, NULL, 2.000, 11.0000, 0.00, 2.00, 22.00),
(103, 1, 3, 1017, NULL, 1.000, 13.2000, 0.00, 1.20, 13.20),
(104, 2, 1, 1010, NULL, 1.000, 55.0000, 0.00, 5.00, 55.00),
(105, 2, 2, 1013, NULL, 1.000, 88.0000, 0.00, 8.00, 88.00),
(106, 2, 3, 1009, NULL, 1.000, 24.2000, 2.20, 2.00, 22.00),
(107, 3, 1, 1001, NULL, 1.000, 33.0000, 0.00, 3.00, 33.00),
(108, 3, 2, 1006, NULL, 2.000, 16.5000, 0.00, 3.00, 33.00),
(109, 3, 3, 1007, NULL, 1.000, 19.8000, 0.00, 1.80, 19.80),
(110, 4, 1, 1002, NULL, 1.000, 35.2000, 0.00, 3.20, 35.20),
(111, 4, 2, 1015, NULL, 1.000, 110.0000, 5.50, 9.50, 104.50),
(112, 5, 1, 1012, NULL, 1.000, 71.5000, 0.00, 6.50, 71.50),
(113, 5, 2, 1016, NULL, 2.000, 30.8000, 0.00, 5.60, 61.60),
(114, 6, 1, 1003, 101, -1.000, 44.0000, 0.00, -4.00, -44.00),
(115, 6, 2, 1017, 103, -1.000, 13.2000, 0.00, -1.20, -13.20);

SELECT COUNT(*) AS store_count FROM store;
SELECT COUNT(*) AS staff_count FROM staff;
SELECT COUNT(*) AS product_count FROM product;
SELECT COUNT(*) AS customer_count FROM customer;
SELECT COUNT(*) AS sales_header_count FROM sales_header;
SELECT COUNT(*) AS sales_line_count FROM sales_line;
SELECT COUNT(*) AS online_order_header_count FROM online_order_header;
SELECT COUNT(*) AS online_order_line_count FROM online_order_line;
