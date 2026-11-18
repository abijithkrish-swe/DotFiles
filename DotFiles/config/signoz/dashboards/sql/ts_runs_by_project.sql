SELECT
  attributes_string['toolshelf.project'] AS project,
  attributes_string['toolshelf.tools'] AS tools,
  count() AS runs,
  countIf(has_error) AS failed,
  round(sum(duration_nano) / 1e9) AS total_s
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}})) AND fromUnixTimestamp64Nano(toInt64({{.end_timestamp_nano}}))
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND resources_string['service.name'] = 'toolshelf' AND name = 'toolshelf.run'
GROUP BY project, tools
ORDER BY runs DESC
LIMIT 30
