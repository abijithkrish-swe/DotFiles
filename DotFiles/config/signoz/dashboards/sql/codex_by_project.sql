-- Codex sends no repo field. Its only folder is `cwd` on the app server's
-- run_sampling_request spans; other spans in the same trace carry the
-- conversation id, which the log events have too. Project = last folder of cwd.
-- client: cli = Codex CLI (originator codex-tui), app = the ChatGPT/Codex app.
WITH conv_project AS (
  SELECT coalesce(nullIf(t.attributes_string['conversation.id'], ''),
                  nullIf(t.attributes_string['thread.id'], ''),
                  t.attributes_string['thread_id']) AS conv,
         any(s.cwd) AS cwd
  FROM (
    SELECT DISTINCT trace_id, attributes_string['cwd'] AS cwd
    FROM signoz_traces.distributed_signoz_index_v3
    WHERE serviceName = 'codex-app-server' AND name = 'run_sampling_request'
      AND attributes_string['cwd'] != ''
      AND timestamp > now() - INTERVAL 90 DAY
  ) AS s
  INNER JOIN signoz_traces.distributed_signoz_index_v3 AS t ON t.trace_id = s.trace_id
  WHERE t.serviceName = 'codex-app-server' AND t.timestamp > now() - INTERVAL 90 DAY
    AND (t.attributes_string['conversation.id'] != '' OR t.attributes_string['thread.id'] != ''
         OR t.attributes_string['thread_id'] != '')
  GROUP BY conv
),
per_conv AS (
  SELECT
    l.attributes_string['conversation.id'] AS conv,
    if(anyIf(l.attributes_string['originator'], l.attributes_string['originator'] != '') = 'codex-tui', 'cli', 'app') AS client,
    countIf(l.attributes_string['event.name'] = 'codex.user_prompt') AS prompts,
    countIf(l.attributes_string['event.name'] = 'codex.tool_result') AS tool_calls,
    sum(toUInt64OrZero(l.attributes_string['input_token_count'])) AS input_tokens,
    sum(toUInt64OrZero(l.attributes_string['output_token_count'])) AS output_tokens,
    max(l.timestamp) AS last_ts
  FROM signoz_logs.distributed_logs_v2 AS l
  WHERE l.timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
    AND l.ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
    AND l.resources_string['service.name'] LIKE 'codex%'
    AND l.attributes_string['conversation.id'] != ''
  GROUP BY conv
)
SELECT
  multiIf(p.cwd = '', '(unknown)', p.cwd = '/', '(no folder)', arrayElement(splitByChar('/', p.cwd), -1)) AS project,
  c.client AS client,
  count() AS conversations,
  sum(c.prompts) AS prompts,
  sum(c.tool_calls) AS tool_calls,
  sum(c.input_tokens) AS input_tokens,
  sum(c.output_tokens) AS output_tokens,
  formatDateTime(toTimeZone(fromUnixTimestamp64Nano(max(c.last_ts)), 'Asia/Kolkata'), '%Y-%m-%d %H:%i') AS last_used_ist
FROM per_conv AS c
LEFT JOIN conv_project AS p ON p.conv = c.conv
GROUP BY project, client
ORDER BY output_tokens DESC, conversations DESC
