-- Each rate-limit error, with what that config used in the 5 hours before it:
-- an empirical view of the plan's 5-hour allowance.
WITH hits AS (
  SELECT timestamp AS hit_ts,
         resources_string['agent.config'] AS agent_config,
         attributes_string['anthropic.plan'] AS plan,
         attributes_string['model'] AS model
  FROM signoz_logs.distributed_logs_v2
  WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
    AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
    AND attributes_string['event.name'] = 'api_error'
    AND attributes_string['error'] LIKE '%rate limit%'
),
reqs AS (
  SELECT timestamp AS ts,
         resources_string['agent.config'] AS agent_config,
         attributes_number['cost_usd'] AS cost,
         attributes_number['output_tokens'] AS output_tokens
  FROM signoz_logs.distributed_logs_v2
  WHERE timestamp BETWEEN {{.start_timestamp_nano}} - 5 * 3600 * 1000000000 AND {{.end_timestamp_nano}}
    AND ts_bucket_start BETWEEN {{.start_timestamp}} - 5 * 3600 - 1800 AND {{.end_timestamp}}
    AND attributes_string['event.name'] = 'api_request'
)
SELECT
  fromUnixTimestamp64Nano(h.hit_ts) AS hit_at,
  h.agent_config AS agent_config,
  h.plan AS plan,
  h.model AS model,
  countIf(r.ts BETWEEN h.hit_ts - 5 * 3600 * 1000000000 AND h.hit_ts) AS requests_prev_5h,
  round(sumIf(r.cost, r.ts BETWEEN h.hit_ts - 5 * 3600 * 1000000000 AND h.hit_ts), 2) AS api_equiv_usd_prev_5h,
  sumIf(r.output_tokens, r.ts BETWEEN h.hit_ts - 5 * 3600 * 1000000000 AND h.hit_ts) AS output_tokens_prev_5h
FROM hits AS h
INNER JOIN reqs AS r ON r.agent_config = h.agent_config
GROUP BY hit_at, agent_config, plan, model
ORDER BY hit_at DESC
LIMIT 30
