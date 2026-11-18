SELECT
  attributes_string['model'] AS model,
  count() AS requests,
  round(quantile(0.5)(attributes_number['duration_ms'])) AS p50_ms,
  round(quantile(0.95)(attributes_number['duration_ms'])) AS p95_ms,
  round(quantile(0.5)(attributes_number['ttft_ms'])) AS p50_ttft_ms,
  round(quantile(0.95)(attributes_number['ttft_ms'])) AS p95_ttft_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY model
ORDER BY requests DESC
