SELECT
  if(attributes_string['mcp_server'] = '', attributes_string['tool_name'],
     concat('mcp:', attributes_string['mcp_server'], '/', attributes_string['tool_name'])) AS tool,
  count() AS calls,
  round(100 * countIf(attributes_string['success'] = 'true') / count(), 1) AS success_pct,
  round(quantile(0.5)(toFloat64OrZero(attributes_string['duration_ms']))) AS p50_ms,
  round(quantile(0.95)(toFloat64OrZero(attributes_string['duration_ms']))) AS p95_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'codex.tool_result'
GROUP BY tool
ORDER BY calls DESC
LIMIT 25
