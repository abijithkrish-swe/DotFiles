SELECT
  attributes_string['toolshelf.command.name'] AS program,
  resources_string['agent.client'] AS client,
  resources_string['agent.config'] AS agent_config,
  attributes_string['toolshelf.mode'] AS mode,
  count() AS runs,
  countIf(has_error) AS failed,
  round(quantile(0.5)(duration_nano) / 1e6) AS p50_ms,
  round(quantile(0.95)(duration_nano) / 1e6) AS p95_ms
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}})) AND fromUnixTimestamp64Nano(toInt64({{.end_timestamp_nano}}))
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND resources_string['service.name'] = 'toolshelf' AND name = 'toolshelf.run'
GROUP BY program, client, agent_config, mode
ORDER BY runs DESC
LIMIT 30
