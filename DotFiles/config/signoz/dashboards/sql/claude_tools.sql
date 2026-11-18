SELECT
  multiIf(
    attributes_string['tool_name'] = 'mcp_tool',
      concat('mcp:', JSONExtractString(attributes_string['tool_parameters'], 'mcp_server_name'),
             '/', JSONExtractString(attributes_string['tool_parameters'], 'mcp_tool_name')),
    attributes_string['tool_name'] = 'Bash',
      concat('bash:', replaceRegexpOne(arrayFirst(w -> NOT match(w, '^\\w+='), splitByWhitespace(replaceRegexpOne(JSONExtractString(attributes_string['tool_parameters'], 'full_command'), '^(\\s*cd\\s+\\S+\\s*(&&|;)\\s*)+', ''))), '^.*/', '')),
    attributes_string['tool_name']) AS tool,
  resources_string['agent.config'] AS agent_config,
  count() AS calls,
  round(100 * countIf(attributes_string['success'] = 'true') / count(), 1) AS success_pct,
  round(quantile(0.5)(toFloat64OrZero(attributes_string['duration_ms']))) AS p50_ms,
  round(quantile(0.95)(toFloat64OrZero(attributes_string['duration_ms']))) AS p95_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'tool_result'
GROUP BY tool, agent_config
ORDER BY calls DESC
LIMIT 40
