SELECT
  resources_string['agent.config'] AS agent_config,
  any(attributes_string['anthropic.plan']) AS plan,
  uniqExactIf(toDate(fromUnixTimestamp64Nano(timestamp), 'Asia/Kolkata'), attributes_string['event.name'] = 'api_request') AS active_days,
  countIf(attributes_string['event.name'] = 'user_prompt') AS prompts,
  countIf(attributes_string['event.name'] = 'api_request') AS api_requests,
  round(sumIf(attributes_number['cost_usd'], attributes_string['event.name'] = 'api_request'), 2) AS api_equiv_usd,
  round(api_equiv_usd / nullIf(active_days, 0), 2) AS usd_per_active_day,
  round(prompts / nullIf(active_days, 0), 1) AS prompts_per_active_day,
  round(sumIf(attributes_number['output_tokens'], attributes_string['event.name'] = 'api_request') / nullIf(active_days, 0)) AS output_tokens_per_day,
  round(api_equiv_usd / nullIf(prompts, 0), 2) AS usd_per_prompt
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND resources_string['service.name'] = 'claude-code'
  AND attributes_string['event.name'] IN ('api_request', 'user_prompt')
GROUP BY agent_config
ORDER BY agent_config
