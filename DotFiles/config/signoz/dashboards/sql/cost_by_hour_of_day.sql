SELECT
  toHour(fromUnixTimestamp64Nano(timestamp), 'Asia/Kolkata') AS hour_ist,
  round(sumIf(attributes_number['cost_usd'], resources_string['agent.config'] = 'claude'), 2) AS claude_usd,
  round(sumIf(attributes_number['cost_usd'], resources_string['agent.config'] = 'myclaude'), 2) AS myclaude_usd,
  countIf(resources_string['agent.config'] = 'claude') AS claude_requests,
  countIf(resources_string['agent.config'] = 'myclaude') AS myclaude_requests
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY hour_ist
ORDER BY hour_ist
