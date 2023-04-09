-- Check transaction_base
SELECT
transaction_key-> usage_id transaction_key,
location_id,
customer_id,
TIMESTAMPSUB(hours, 0, time) time,
round(value,-1) value
FROM  TRANSACTION_BASE EMIT CHANGES;
