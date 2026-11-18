SELECT
  timestamp AS time,
  resources_string['agent.client'] AS client,
  resources_string['agent.config'] AS agent_config,
  attributes_string['toolshelf.project'] AS project,
  attributes_string['toolshelf.command.name'] AS program,
  attributes_number['process.exit.code'] AS exit_code,
  status_message AS status,
  substring(attributes_string['toolshelf.command'], 1, 200) AS command,
  attributes_string['toolshelf.run_id'] AS run_id
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}})) AND fromUnixTimestamp64Nano(toInt64({{.end_timestamp_nano}}))
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND resources_string['service.name'] = 'toolshelf' AND name = 'toolshelf.run' AND has_error
ORDER BY timestamp DESC
LIMIT 50
