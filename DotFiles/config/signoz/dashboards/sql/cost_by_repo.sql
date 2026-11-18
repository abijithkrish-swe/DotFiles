SELECT
  if(attributes_string['vcs.repository.name'] = '', '(no repo)', attributes_string['vcs.repository.name']) AS repository,
  resources_string['agent.config'] AS agent_config,
  count() AS requests,
  round(sum(attributes_number['cost_usd']), 2) AS cost_usd
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY repository, agent_config
ORDER BY cost_usd DESC
LIMIT 20
