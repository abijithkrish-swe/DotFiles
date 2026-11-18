SELECT sum(attributes_number['cost_usd']) AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp >= toUnixTimestamp(toStartOfDay(now(), 'Asia/Kolkata')) * 1000000000
  AND ts_bucket_start >= toUnixTimestamp(toStartOfDay(now(), 'Asia/Kolkata')) - 1800
  AND attributes_string['event.name'] = 'api_request'
