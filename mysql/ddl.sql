-- MySQL 8 OLTP for ausie_retail_oltp
-- Source layer: POS / ERP / CRM / online → later DLT → DuckDB bronze
-- Run once in Workbench (Query tab → Execute). Re-run of ALTER/INDEX will fail if objects already exist.

USE ausie_retail_oltp;

-- 1. Tables

CREATE TABLE IF NOT EXISTS store (
    store_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    store_code          VARCHAR(50) NOT NULL,
    store_name          VARCHAR(150) NOT NULL,
    channel             VARCHAR(20) NOT NULL DEFAULT 'offline',
    timezone_name       VARCHAR(64) NOT NULL DEFAULT 'Australia/Sydney',
    address_line_1      VARCHAR(200) NULL,
    address_line_2      VARCHAR(200) NULL,
    suburb              VARCHAR(100) NULL,
    state_text          VARCHAR(100) NULL,
    postcode_text       VARCHAR(20) NULL,
    country_code        CHAR(2) NOT NULL DEFAULT 'AU',
    phone               VARCHAR(50) NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (store_id)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS staff (
    staff_version_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    staff_id            BIGINT UNSIGNED NOT NULL,
    staff_number        VARCHAR(50) NOT NULL,
    store_id            BIGINT UNSIGNED NULL,
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(254) NULL,
    role_name           VARCHAR(100) NULL,
    state_text          VARCHAR(100) NULL,
    effective_from      DATETIME(6) NOT NULL,
    effective_to        DATETIME(6) NULL,
    is_current          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (staff_version_id),
    CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS product (
    product_version_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id          BIGINT UNSIGNED NOT NULL,
    sku                 VARCHAR(80) NOT NULL,
    product_name        VARCHAR(255) NOT NULL,
    category_name       VARCHAR(150) NULL,
    brand_name          VARCHAR(150) NULL,
    unit_of_measure     VARCHAR(30) NOT NULL DEFAULT 'EA',
    unit_cost_ex_gst    DECIMAL(13,4) NULL,
    unit_price_ex_gst   DECIMAL(13,4) NOT NULL,
    gst_rate            DECIMAL(7,6) NOT NULL DEFAULT 0.100000,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from      DATETIME(6) NOT NULL,
    effective_to        DATETIME(6) NULL,
    is_current          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (product_version_id),
    CHECK (unit_cost_ex_gst IS NULL OR unit_cost_ex_gst >= 0),
    CHECK (unit_price_ex_gst >= 0),
    CHECK (gst_rate >= 0),
    CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS customer (
    customer_id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_number     VARCHAR(80) NULL,
    first_name          VARCHAR(100) NULL,
    last_name           VARCHAR(100) NULL,
    email               VARCHAR(254) NULL,
    phone               VARCHAR(50) NULL,
    address_line_1      VARCHAR(200) NULL,
    address_line_2      VARCHAR(200) NULL,
    suburb              VARCHAR(100) NULL,
    state_text          VARCHAR(100) NULL,
    postcode_text       VARCHAR(20) NULL,
    country_code        CHAR(2) NOT NULL DEFAULT 'AU',
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (customer_id)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS sales_header (
    sales_header_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    transaction_number          VARCHAR(100) NOT NULL,
    source_system               VARCHAR(50) NOT NULL,
    source_event_id             VARCHAR(150) NOT NULL,
    store_id                    BIGINT UNSIGNED NOT NULL,
    staff_version_id            BIGINT UNSIGNED NULL,
    customer_id                 BIGINT UNSIGNED NULL,
    original_sales_header_id    BIGINT UNSIGNED NULL,
    transaction_type            VARCHAR(20) NOT NULL DEFAULT 'SALE',
    transaction_at              DATETIME(6) NOT NULL,
    subtotal_inc_gst            DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    discount_inc_gst            DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    gst_amount                  DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    total_inc_gst               DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    state_text                  VARCHAR(100) NULL,
    created_at                  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (sales_header_id),
    CHECK (transaction_type IN ('SALE', 'RETURN'))
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS sales_line (
    sales_line_id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sales_header_id             BIGINT UNSIGNED NOT NULL,
    line_number                 INT UNSIGNED NOT NULL,
    product_version_id          BIGINT UNSIGNED NOT NULL,
    original_sales_line_id      BIGINT UNSIGNED NULL,
    qty                         DECIMAL(12,3) NOT NULL,
    unit_price_inc_gst          DECIMAL(13,4) NOT NULL,
    discount_inc_gst            DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    gst_amount                  DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    line_total_inc_gst          DECIMAL(14,2) NOT NULL,
    created_at                  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (sales_line_id),
    CHECK (qty <> 0)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS online_order_header (
    online_order_header_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_number                        VARCHAR(100) NOT NULL,
    source_system                       VARCHAR(50) NOT NULL,
    source_event_id                     VARCHAR(150) NOT NULL,
    customer_id                         BIGINT UNSIGNED NULL,
    fulfilment_store_id                 BIGINT UNSIGNED NULL,
    original_online_order_header_id     BIGINT UNSIGNED NULL,
    order_type                          VARCHAR(20) NOT NULL DEFAULT 'SALE',
    order_status                        VARCHAR(40) NOT NULL,
    order_at                            DATETIME(6) NOT NULL,
    subtotal_inc_gst                    DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    discount_inc_gst                    DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    shipping_inc_gst                    DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    gst_amount                          DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    total_inc_gst                       DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    shipping_name                       VARCHAR(200) NULL,
    shipping_address_line_1             VARCHAR(200) NULL,
    shipping_address_line_2             VARCHAR(200) NULL,
    shipping_suburb                     VARCHAR(100) NULL,
    shipping_state_text                 VARCHAR(100) NULL,
    shipping_postcode_text              VARCHAR(20) NULL,
    shipping_country_code               CHAR(2) NOT NULL DEFAULT 'AU',
    created_at                          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at                          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                                ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (online_order_header_id),
    CHECK (order_type IN ('SALE', 'RETURN'))
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS online_order_line (
    online_order_line_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    online_order_header_id          BIGINT UNSIGNED NOT NULL,
    line_number                     INT UNSIGNED NOT NULL,
    product_version_id              BIGINT UNSIGNED NOT NULL,
    original_online_order_line_id   BIGINT UNSIGNED NULL,
    qty                             DECIMAL(12,3) NOT NULL,
    unit_price_inc_gst              DECIMAL(13,4) NOT NULL,
    discount_inc_gst                DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    gst_amount                      DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    line_total_inc_gst              DECIMAL(14,2) NOT NULL,
    created_at                      DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (online_order_line_id),
    CHECK (qty <> 0)
) ENGINE=InnoDB;


-- 2. Foreign keys

ALTER TABLE staff
    ADD CONSTRAINT fk_staff_store
        FOREIGN KEY (store_id)
        REFERENCES store (store_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL;


ALTER TABLE sales_header
    ADD CONSTRAINT fk_sales_header_store
        FOREIGN KEY (store_id)
        REFERENCES store (store_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales_header_staff
        FOREIGN KEY (staff_version_id)
        REFERENCES staff (staff_version_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,
    ADD CONSTRAINT fk_sales_header_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer (customer_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,
    ADD CONSTRAINT fk_sales_header_original
        FOREIGN KEY (original_sales_header_id)
        REFERENCES sales_header (sales_header_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL;


ALTER TABLE sales_line
    ADD CONSTRAINT fk_sales_line_header
        FOREIGN KEY (sales_header_id)
        REFERENCES sales_header (sales_header_id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,
    ADD CONSTRAINT fk_sales_line_product
        FOREIGN KEY (product_version_id)
        REFERENCES product (product_version_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    ADD CONSTRAINT fk_sales_line_original
        FOREIGN KEY (original_sales_line_id)
        REFERENCES sales_line (sales_line_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL;


ALTER TABLE online_order_header
    ADD CONSTRAINT fk_online_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer (customer_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,
    ADD CONSTRAINT fk_online_order_store
        FOREIGN KEY (fulfilment_store_id)
        REFERENCES store (store_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL,
    ADD CONSTRAINT fk_online_order_original
        FOREIGN KEY (original_online_order_header_id)
        REFERENCES online_order_header (online_order_header_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL;


ALTER TABLE online_order_line
    ADD CONSTRAINT fk_online_order_line_header
        FOREIGN KEY (online_order_header_id)
        REFERENCES online_order_header (online_order_header_id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,
    ADD CONSTRAINT fk_online_order_line_product
        FOREIGN KEY (product_version_id)
        REFERENCES product (product_version_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    ADD CONSTRAINT fk_online_order_line_original
        FOREIGN KEY (original_online_order_line_id)
        REFERENCES online_order_line (online_order_line_id)
        ON UPDATE RESTRICT
        ON DELETE SET NULL;


-- 3. Indexes
-- Unique on (source_system, source_event_id): OLTP rejects the same event twice.
-- POS retry duplicates for bronze can be injected at DLT/bronze, not as two identical events here.

CREATE UNIQUE INDEX ux_store_store_code
    ON store (store_code);

CREATE INDEX ix_store_channel
    ON store (channel);

CREATE INDEX ix_store_state_text
    ON store (state_text);


CREATE UNIQUE INDEX ux_staff_id_effective_from
    ON staff (staff_id, effective_from);

CREATE INDEX ix_staff_number
    ON staff (staff_number);

CREATE INDEX ix_staff_current
    ON staff (staff_id, is_current);

CREATE INDEX ix_staff_store
    ON staff (store_id);


CREATE UNIQUE INDEX ux_product_id_effective_from
    ON product (product_id, effective_from);

CREATE INDEX ix_product_sku
    ON product (sku);

CREATE INDEX ix_product_current
    ON product (product_id, is_current);

CREATE INDEX ix_product_sku_current
    ON product (sku, is_current);


CREATE UNIQUE INDEX ux_customer_customer_number
    ON customer (customer_number);

CREATE INDEX ix_customer_email
    ON customer (email);

CREATE INDEX ix_customer_phone
    ON customer (phone);

CREATE INDEX ix_customer_state_text
    ON customer (state_text);


CREATE UNIQUE INDEX ux_sales_header_source_event
    ON sales_header (source_system, source_event_id);

CREATE INDEX ix_sales_header_transaction_number
    ON sales_header (transaction_number);

CREATE INDEX ix_sales_header_transaction_at
    ON sales_header (transaction_at);

CREATE INDEX ix_sales_header_store_transaction_at
    ON sales_header (store_id, transaction_at);

CREATE INDEX ix_sales_header_customer
    ON sales_header (customer_id);

CREATE INDEX ix_sales_header_staff
    ON sales_header (staff_version_id);

CREATE INDEX ix_sales_header_original
    ON sales_header (original_sales_header_id);


CREATE UNIQUE INDEX ux_sales_line_header_line
    ON sales_line (sales_header_id, line_number);

CREATE INDEX ix_sales_line_product
    ON sales_line (product_version_id);

CREATE INDEX ix_sales_line_original
    ON sales_line (original_sales_line_id);


CREATE UNIQUE INDEX ux_online_order_source_event
    ON online_order_header (source_system, source_event_id);

CREATE INDEX ix_online_order_number
    ON online_order_header (order_number);

CREATE INDEX ix_online_order_at
    ON online_order_header (order_at);

CREATE INDEX ix_online_order_customer
    ON online_order_header (customer_id);

CREATE INDEX ix_online_order_store
    ON online_order_header (fulfilment_store_id);

CREATE INDEX ix_online_order_status
    ON online_order_header (order_status);

CREATE INDEX ix_online_order_original
    ON online_order_header (original_online_order_header_id);


CREATE UNIQUE INDEX ux_online_order_line_header_line
    ON online_order_line (online_order_header_id, line_number);

CREATE INDEX ix_online_order_line_product
    ON online_order_line (product_version_id);

CREATE INDEX ix_online_order_line_original
    ON online_order_line (original_online_order_line_id);
