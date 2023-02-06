ALTER SYSTEM
SET max_wal_senders = '250';
ALTER SYSTEM
SET wal_sender_timeout = '60s';
ALTER SYSTEM
SET max_replication_slots = '250';
ALTER SYSTEM
SET wal_level = 'logical';
CREATE SCHEMA atm_locations;
SET search_path TO atm_locations;
CREATE EXTENSION postgis;
CREATE EXTENSION pg_cron;
-- # create and populate atm_locations data table
CREATE TABLE atm_locations (
    location_id VARCHAR(255) PRIMARY KEY,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(255),
    zip_code VARCHAR(255),
    daily_transactions INT
);
COPY atm_locations(location_id, latitude, longitude)
FROM '/data/atm_locations.csv' DELIMITER ',' CSV HEADER;
-- # create and populate customers data table
CREATE TABLE customers (
    id VARCHAR(255) PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(255)
);
COPY customers(id, first_name, last_name, email, phone)
FROM '/data/customers.csv' DELIMITER ',' CSV HEADER;
-- # create atm_usage table which data will be generated to over time
CREATE TABLE atm_usage (
    usage_id VARCHAR(255) PRIMARY KEY,
    location_id INT,
    customer_id VARCHAR(255),
    value DOUBLE PRECISION,
    time TIMESTAMP
);
-- #
-- add weighting for fraud
SELECT *,
    random() as fraudulent_weight INTO location
FROM atm_locations.atm_locations -- #
CREATE OR REPLACE PROCEDURE generate_atm_usage() AS $$
DECLARE location atm_locations.atm_locations %ROWTYPE;
customer atm_locations.customers %ROWTYPE;
uuid VARCHAR;
value INTEGER;
BEGIN FOR i IN 0..60 BY 1 LOOP BEGIN
SELECT * INTO location
FROM atm_locations.atm_locations
ORDER BY fraudulent_weight * random()
LIMIT 1;
SELECT * INTO customer
FROM atm_locations.customers
ORDER BY random()
LIMIT 1;
SELECT uuid_in(
        md5(random()::text || clock_timestamp()::text)::cstring
    ) INTO uuid;
value := (floor(random() * 191) + 10) * 10;
INSERT INTO atm_locations.atm_usage (usage_id, location_id, customer_id, value, time)
VALUES (
        uuid,
        location.location_id,
        customer.id,
        value,
        NOW()
    );
COMMIT;
PERFORM pg_sleep(1);
END;
END LOOP;
END;
$$ LANGUAGE plpgsql;
-- #
SELECT cron.schedule(
        'mrclean',
        '0 */6 * * *',
        $$DELETE
        FROM atm_locations.atm_usage
        WHERE create_time < now() - interval '6 hours' $$
    );
SELECT cron.schedule(
        'new_order_creation',
        '*/1 * * * *',
        $$CALL atm_locations.generate_atm_usage() $$
    );
