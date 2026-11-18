SELECT
  toStartOfInterval(timestamp, INTERVAL 1 HOUR) AS ts,
  name AS phase,
  quantile(0.95)(duration_nano) / 1e6 AS value
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}})) AND fromUnixTimestamp64Nano(toInt64({{.end_timestamp_nano}}))
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND resources_string['service.name'] = 'toolshelf'
GROUP BY ts, phase
ORDER BY ts
