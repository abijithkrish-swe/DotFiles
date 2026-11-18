SELECT
  if(event = 'tool_result', concat('claude-code ', agent_config), 'codex') AS agent,
  server, tool, count() AS calls
FROM (
  SELECT
    attributes_string['event.name'] AS event,
    resources_string['agent.config'] AS agent_config,
    if(event = 'tool_result', JSONExtractString(attributes_string['tool_parameters'], 'mcp_server_name'), attributes_string['mcp_server']) AS server,
    if(event = 'tool_result', JSONExtractString(attributes_string['tool_parameters'], 'mcp_tool_name'), attributes_string['tool_name']) AS tool
  FROM signoz_logs.distributed_logs_v2
  WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
    AND ((attributes_string['event.name'] = 'tool_result' AND attributes_string['tool_name'] = 'mcp_tool')
      OR (attributes_string['event.name'] = 'codex.tool_result' AND attributes_string['mcp_server'] != ''))
)
GROUP BY agent, server, tool
ORDER BY calls DESC
LIMIT 30
