-- trasaction stream
CREATE STREAM transaction_base (
transaction_key STRUCT<usage_id VARCHAR> KEY,
location_id VARCHAR,
value double,
customer_id VARCHAR,
time TIMESTAMP
) WITH (
KAFKA_TOPIC='postgres.atm_locations.atm_usage',
KEY_FORMAT='JSON',
VALUE_FORMAT='JSON_SR'
);

-- Check transaction_base
SELECT
transaction_key-> usage_id transaction_key,
location_id,
customer_id,
TIMESTAMPSUB(hours, 5, time) time,
round(value,-1) value
FROM  TRANSACTION_BASE EMIT CHANGES;

-- rekey transaction_base
CREATE STREAM atm_usage_rekeyed WITH (
KAFKA_TOPIC='atm_usage_rekeyed',
KEY_FORMAT='KAFKA',
VALUE_FORMAT='JSON_SR'
) AS SELECT
transaction_key-> usage_id transaction_key,
location_id,
customer_id,
TIMESTAMPSUB(hours, 6, time) time,
value
FROM  TRANSACTION_BASE
PARTITION BY transaction_key-> usage_id
EMIT CHANGES;

-- rekey transaction_base with second table
CREATE STREAM atm_usage_rekeyed2 WITH (
KAFKA_TOPIC='atm_usage_rekeyed2',
KEY_FORMAT='KAFKA',
VALUE_FORMAT='JSON_SR'
) AS SELECT
transaction_key-> usage_id transaction_key,
location_id,
customer_id,
TIMESTAMPSUB(hours, 6, time) time,
value
FROM  TRANSACTION_BASE
PARTITION BY transaction_key-> usage_id
EMIT CHANGES;

-- create customer stream
CREATE STREAM customers_base (
    struct_key STRUCT<id VARCHAR> KEY,
    id VARCHAR, first_name VARCHAR, last_name VARCHAR, email VARCHAR, phone VARCHAR
  ) WITH (
KAFKA_TOPIC='postgres.atm_locations.customers',
KEY_FORMAT='JSON',
VALUE_FORMAT='JSON_SR'
);

-- rekey customer stream
CREATE STREAM customers_rekeyed WITH (
KAFKA_TOPIC='customers_rekeyed',
KEY_FORMAT='KAFKA',
VALUE_FORMAT='JSON_SR'
) AS SELECT
struct_key-> id,
first_name,
last_name,
phone,
email
FROM  CUSTOMERS_BASE
PARTITION BY struct_key-> id
EMIT CHANGES;

-- create customer table
CREATE TABLE customers_tbl WITH (
KAFKA_TOPIC='customers_tbl',
KEY_FORMAT='JSON_SR',
VALUE_FORMAT='JSON_SR'
) AS
SELECT
    id_1,
    EARLIEST_BY_OFFSET(first_name) first_name,
    EARLIEST_BY_OFFSET(last_name) last_name,
    EARLIEST_BY_OFFSET(email) email,
    EARLIEST_BY_OFFSET(phone) phone    FROM  CUSTOMERS_REKEYED
GROUP BY id_1
EMIT CHANGES;

-- create location stream
CREATE STREAM location_base (
    struct_key STRUCT<location_id INT> KEY,
    latitude DOUBLE, 
  longitude DOUBLE, 
  address VARCHAR, 
  city VARCHAR,
  state VARCHAR,
  zip_code VARCHAR,
  daily_transactions INT
  ) WITH (
KAFKA_TOPIC='postgres.atm_locations.atm_locations',
KEY_FORMAT='JSON',
VALUE_FORMAT='JSON_SR'
);

-- locations rekeyed
CREATE STREAM locations_rekeyed WITH (
KAFKA_TOPIC='locations_rekeyed',
KEY_FORMAT='KAFKA',
VALUE_FORMAT='JSON_SR'
) AS SELECT
struct_key-> location_id,
latitude,
longitude,
address,
city,
state,
zip_code,
daily_transactions
FROM  location_base
PARTITION BY struct_key-> location_id
EMIT CHANGES;

-- create location table
CREATE TABLE locations_tbl WITH (
KAFKA_TOPIC='locations_tbl',
KEY_FORMAT='JSON_SR',
VALUE_FORMAT='JSON_SR'
) AS
SELECT
    location_id,
    EARLIEST_BY_OFFSET(latitude) latitude,
    EARLIEST_BY_OFFSET(longitude) longitude,
    EARLIEST_BY_OFFSET(address) address,
    EARLIEST_BY_OFFSET(city) city,
    EARLIEST_BY_OFFSET(state) state,
    EARLIEST_BY_OFFSET(zip_code) zip_code,
    EARLIEST_BY_OFFSET(daily_transactions) daily_transactions
    
    FROM  locations_REKEYED
GROUP BY location_id
EMIT CHANGES;

-- id fraudulent transactions
CREATE stream potential_fraud WITH (
KAFKA_TOPIC='potential_fraud',
KEY_FORMAT='JSON_SR',
VALUE_FORMAT='JSON_SR'
) as 
SELECT
atm1.*

FROM ATM_USAGE_REKEYED atm1
inner join  ATM_USAGE_REKEYED2 atm2
WITHIN 10 MINUTES
on atm1.CUSTOMER_ID = atm2.customer_id
where atm1.transaction_key != atm2.transaction_key
EMIT CHANGES;

-- enricher
create stream potential_fraud_enriched WITH (
KAFKA_TOPIC='potential_fraud_enriched',
KEY_FORMAT='JSON_SR',
VALUE_FORMAT='JSON_SR'
)
as select
*
from  POTENTIAL_FRAUD f
INNER join  CUSTOMERS_TBL  c
on f.ATM1_CUSTOMER_ID = c.id_1
inner join  LOCATIONS_TBL  l
on l.location_id = cast(f.ATM1_LOCATION_ID as INT)
EMIT CHANGES;
