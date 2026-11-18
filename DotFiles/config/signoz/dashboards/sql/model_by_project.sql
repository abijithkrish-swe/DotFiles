SELECT
  if(attributes_string['vcs.repository.name'] = '', '(no repo)', attributes_string['vcs.repository.name']) AS project,
  attributes_string['model'] AS model,
  resources_string['agent.config'] AS agent_config,
  count() AS requests,
  round(100 * count() / sum(count()) OVER (PARTITION BY project, agent_config), 1) AS pct_of_project_requests,
  round(sum(attributes_number['cost_usd']), 2) AS cost_usd,
  sum(attributes_number['output_tokens']) AS output_tokens
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY project, model, agent_config
ORDER BY project, cost_usd DESC
