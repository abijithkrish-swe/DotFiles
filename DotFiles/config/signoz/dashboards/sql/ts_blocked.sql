SELECT
  fromUnixTimestamp64Nano(timestamp) AS time,
  resources_string['agent.client'] AS client,
  attributes_string['toolshelf.project'] AS project,
  attributes_string['toolshelf.block_reason'] AS reason,
  attributes_string['toolshelf.command'] AS command
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'toolshelf.blocked'
ORDER BY timestamp DESC
LIMIT 50
