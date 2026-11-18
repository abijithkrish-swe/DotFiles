SELECT
  resources_string['agent.config'] AS agent_config,
  sum(attributes_number['cache_read_tokens']) AS cache_read,
  sum(attributes_number['input_tokens'] + attributes_number['cache_creation_tokens']) AS uncached_input,
  sum(attributes_number['output_tokens']) AS output,
  round(100 * cache_read / nullIf(cache_read + uncached_input, 0), 1) AS cache_hit_pct
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY agent_config
