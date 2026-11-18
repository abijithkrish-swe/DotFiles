SELECT
  toStartOfDay(fromUnixTimestamp64Nano(timestamp), 'Asia/Kolkata') AS ts,
  resources_string['agent.config'] AS agent_config,
  sum(attributes_number['cost_usd']) AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY ts, agent_config
ORDER BY ts
