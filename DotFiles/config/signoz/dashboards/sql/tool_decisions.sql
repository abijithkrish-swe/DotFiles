SELECT
  attributes_string['tool_name'] AS tool,
  resources_string['agent.config'] AS agent_config,
  attributes_string['decision_type'] AS decision,
  attributes_string['decision_source'] AS decided_by,
  count() AS times
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'tool_decision'
GROUP BY tool, agent_config, decision, decided_by
ORDER BY times DESC
LIMIT 30
