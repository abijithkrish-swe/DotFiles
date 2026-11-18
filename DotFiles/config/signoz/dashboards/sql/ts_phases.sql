SELECT
  name AS phase,
  count() AS spans,
  round(quantile(0.5)(duration_nano) / 1e6, 1) AS p50_ms,
  round(quantile(0.95)(duration_nano) / 1e6, 1) AS p95_ms,
  round(100 * countIf(has_error) / count(), 1) AS error_pct
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}})) AND fromUnixTimestamp64Nano(toInt64({{.end_timestamp_nano}}))
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND resources_string['service.name'] = 'toolshelf'
GROUP BY phase
ORDER BY p95_ms DESC
