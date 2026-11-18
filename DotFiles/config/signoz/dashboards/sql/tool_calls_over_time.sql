SELECT
  toStartOfInterval(fromUnixTimestamp64Nano(timestamp), INTERVAL 1 HOUR) AS ts,
  if(resources_string['service.name'] = 'claude-code', resources_string['agent.config'], 'codex') AS source,
  count() AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] IN ('tool_result', 'codex.tool_result')
GROUP BY ts, source
ORDER BY ts
