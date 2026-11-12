# Observability: building the AI-usage dashboard and alerts

A hands-on guide: you build one dashboard and two alerts in SigNoz
(`http://localhost:18080`) and learn the concepts on the way. Every query here
was tested against this machine's data on 2026-11-13. What is collected, and
why: `Observability.md`.

## 1. Concepts first (10 minutes)

### Three signals, three tables

| Signal | Answers | Here | ClickHouse table |
|---|---|---|---|
| **Metrics:** numbers over time, pre-aggregated | "how much, how fast is it growing" | `claude_code.cost.usage`, `claude_code.token.usage`, `codex.turn.token_usage.sum` | `signoz_metrics.*` |
| **Logs / events:** one record per thing that happened | "which ones, with what details" | `api_request` (cost, tokens, latency per call), `tool_result`, `toolshelf.blocked` | `signoz_logs.distributed_logs_v2` |
| **Traces:** a tree of timed spans per operation | "where did the time go" | `toolshelf.run` → check → prepare → exec | `signoz_traces.distributed_signoz_index_v3` |

Rule of thumb: **trends come from metrics, breakdowns and top-N lists from
events, and "why was this one slow" from traces.** Claude Code's cost is in both
a metric and events, so you can compare the two ways.

### Two ways to write a panel query

- **Query Builder:** pick a metric or field and an aggregation, and SigNoz
  writes the SQL. Fast, and it teaches the vocabulary. Use it for metrics.
- **ClickHouse SQL:** full control: computed columns, percentages, joins of
  fields. Use it for top-N tables and anything the builder can't express. It
  is also the skill that transfers to other stacks.

### Metric vocabulary (the Query Builder asks for these)

- **Counter (Sum, monotonic):** only goes up, e.g. tokens and cost. Claude
  Code and Codex both send **delta** counters: each export carries only what
  happened since the last export.
- **Time aggregation:** how one series is rolled up within each time step.
  `Increase` means how much it grew in that step (use it for cost and tokens).
  `Rate` means per second (use it for throughput).
- **Space aggregation:** how series are combined across labels: `Sum` adds
  `type=input` and `type=output` together unless you **Group by** `type`.
- **Labels / attributes:** what you group and filter by: `agent.config`,
  `model`, `type`, `token_type`, `service.name`.

### Percentiles, not averages (SRE habit)

The average API call hides the slow ones. p50 is the typical call; p95 is
what the slowest 1 in 20 feels like. For latency, show both. An average is fine
for money (cost per request).

### RED, the standard service view

**R**ate (calls/s), **E**rrors (% failed), **D**uration (p50/p95). SigNoz's
collector computes RED for every span name automatically (`signoz_calls_total`,
`signoz_latency`), which is what the **Services** page shows for `toolshelf`.

### Variables in ClickHouse panels

SigNoz substitutes the dashboard's time range:
`$start_timestamp` / `$end_timestamp` (seconds) and `$start_timestamp_nano` /
`$end_timestamp_nano`.

- **Logs** have `timestamp` in nanoseconds (a number).
- **Traces** have a DateTime64, so the trace queries wrap the variable:
  `fromUnixTimestamp64Nano(toInt64($start_timestamp_nano))`.
- **`ts_bucket_start`** is the partition key (seconds). Always filter it too,
  so ClickHouse skips old data (the `- 1800` covers the 30-minute bucket).

Time-series SQL panels must return a time column named **`ts`**, a number
named **`value`**, and optional label columns (one line per label value).

**Days are IST:** ClickHouse runs in UTC, so day buckets use
`toStartOfDay(…, 'Asia/Kolkata')`. Otherwise "today" would start at 05:30.

## 2. What we're building

One dashboard, **AI usage**, in five rows:

| Row | Panels | Question it answers |
|---|---|---|
| **Spend** | 1 Cost today (value), 2 Cost per day by config (bars), 3 Cost by model (table) | Is the subscription worth it? Does `myclaude` or `claude` cost more? |
| **Tokens** | 4 Claude tokens by type (builder), 5 Cache hit % (table), 6 Codex tokens by type/model (builder) | Where do tokens go? Is caching working? |
| **Work** | 7 Prompts per day by source, 8 Active time by config (builder) | How much do I actually use each agent? |
| **Tools** | 9 Claude Code top tools, 10 Codex top tools | Which tools and MCPs do I really use, and which fail? |
| **toolshelf** | 11 Runs by program, 12 Time per phase, 13 Blocked commands | What do agents run, what fails, what gets blocked? |
| | + API latency by model (table) | Is the model slow, or my tools? |

Plus two alerts: **daily cost over a threshold**, and **any blocked command**.

## 3. Your first panel, step by step (Query Builder)

**Panel 4, Claude tokens by type:**

1. **Dashboards → + New dashboard.** Name it `AI usage`.
2. **+ New panel → Time Series.**
3. Query tab **Query Builder**, data source **Metrics**.
4. Metric: `claude_code.token.usage`.
5. Time aggregation **Increase**. Space aggregation **Sum**.
6. Group by: `type`. Add `agent.config` too if you want claude and myclaude
   apart.
7. Legend: `{{type}}` (or `{{type}} {{agent.config}}`).
8. Panel settings: title "Claude tokens by type". Y unit: none (it's a
   count). Turn on **stacked**.
9. Save. Time range at the top right: **Last 7 days**.

**What to notice:** `cacheRead` dwarfs everything (cached input is cheap, so
that's good). `output` is small but is priced highest per token.

**Panel 6 (Codex tokens)** is the same recipe: metric
`codex.turn.token_usage.sum`, Increase / Sum, group by `token_type` and
`model`.

**Panel 8 (active time)**: `claude_code.active_time.total`, Increase / Sum,
group by `agent.config` and `type` (`user` = you typing, `cli` = Claude working).
Unit: seconds.

**Try it:** build panel 1 *with the builder* too: `claude_code.cost.usage`,
Increase / Sum, panel type **Value**, reduce to **Sum**, unit **USD**. Then
compare it with the SQL version below. Closed sessions match exactly
(myclaude: $6.797 both ways). A running session's metric trails its events,
since metrics are exported every 15 s and events every 5 s: that was $5.44 vs
$5.66 during this session. **Two pipelines for the same number** is a good
lesson in why you pick one source of truth per panel.

## 4. The SQL panels

For each panel: **+ New panel → choose the type → query tab ClickHouse Query →
paste**.

### 1. Cost today: Value, unit USD

```sql
SELECT sum(attributes_number['cost_usd']) AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp >= toUnixTimestamp(toStartOfDay(now(), 'Asia/Kolkata')) * 1000000000
  AND ts_bucket_start >= toUnixTimestamp(toStartOfDay(now(), 'Asia/Kolkata')) - 1800
  AND attributes_string['event.name'] = 'api_request'
```

Ignores the dashboard time range on purpose: always "since midnight IST".

### 2. Cost per day by config: Bar, unit USD

```sql
SELECT
  toStartOfDay(fromUnixTimestamp64Nano(timestamp), 'Asia/Kolkata') AS ts,
  resources_string['agent.config'] AS agent_config,
  sum(attributes_number['cost_usd']) AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'api_request'
GROUP BY ts, agent_config
ORDER BY ts
```

### 3. Cost by model: Table

```sql
SELECT
  attributes_string['model'] AS model,
  resources_string['agent.config'] AS agent_config,
  count() AS requests,
  round(sum(attributes_number['cost_usd']), 2) AS cost_usd,
  round(avg(attributes_number['cost_usd']), 4) AS avg_cost_per_request
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'api_request'
GROUP BY model, agent_config
ORDER BY cost_usd DESC
```

### 5. Cache hit %: Table

```sql
SELECT
  resources_string['agent.config'] AS agent_config,
  sum(attributes_number['cache_read_tokens']) AS cache_read,
  sum(attributes_number['input_tokens'] + attributes_number['cache_creation_tokens']) AS uncached_input,
  round(100 * cache_read / nullIf(cache_read + uncached_input, 0), 1) AS cache_hit_pct
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'api_request'
GROUP BY agent_config
```

The first run showed 98.6 % (claude) and 89.1 % (myclaude). A sudden drop
means something is breaking the prompt cache: a changed system prompt, MCP
tools reconnecting, or a compaction.

### 7. Prompts per day by source: Bar

```sql
SELECT
  toStartOfDay(fromUnixTimestamp64Nano(timestamp), 'Asia/Kolkata') AS ts,
  if(resources_string['service.name'] = 'claude-code', resources_string['agent.config'], 'codex') AS source,
  count() AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] IN ('user_prompt', 'codex.user_prompt')
GROUP BY ts, source
ORDER BY ts
```

The one panel that compares Claude and Codex like for like (Codex has no cost).

### 9. Claude Code top tools: Table

```sql
SELECT
  multiIf(
    attributes_string['tool_name'] = 'mcp_tool',
      concat('mcp:', JSONExtractString(attributes_string['tool_parameters'], 'mcp_server_name'),
             '/', JSONExtractString(attributes_string['tool_parameters'], 'mcp_tool_name')),
    attributes_string['tool_name'] = 'Bash',
      concat('bash:', replaceRegexpOne(arrayFirst(w -> NOT match(w, '^\w+='), splitByWhitespace(replaceRegexpOne(JSONExtractString(attributes_string['tool_parameters'], 'full_command'), '^(\s*cd\s+\S+\s*(&&|;)\s*)+', ''))), '^.*/', '')),
    attributes_string['tool_name']) AS tool,
  resources_string['agent.config'] AS agent_config,
  count() AS calls,
  round(100 * countIf(attributes_string['success'] = 'true') / count(), 1) AS success_pct,
  round(quantile(0.95)(toFloat64OrZero(attributes_string['duration_ms']))) AS p95_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'tool_result'
GROUP BY tool, agent_config
ORDER BY calls DESC
LIMIT 25
```

What the `multiIf` does:
- Claude Code logs every MCP call as `mcp_tool`, so it pulls the real
  `server/tool` out of `tool_parameters`.
- For Bash it takes the first real program: it skips `cd x &&`, `VAR=value`
  and the path. So `cd x && FOO=1 /usr/bin/git log` counts as `bash:git`.
- Its `duration_ms` is a string, hence `toFloat64OrZero`.

### 10. Codex top tools: Table

```sql
SELECT
  attributes_string['tool_name'] AS tool,
  attributes_string['mcp_server'] AS mcp_server,
  count() AS calls,
  round(100 * countIf(attributes_string['success'] = 'true') / count(), 1) AS success_pct,
  round(quantile(0.95)(toFloat64OrZero(attributes_string['duration_ms']))) AS p95_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'codex.tool_result'
GROUP BY tool, mcp_server
ORDER BY calls DESC
LIMIT 20
```

### 11. toolshelf runs by program: Table

```sql
SELECT
  attributes_string['toolshelf.command.name'] AS program,
  resources_string['agent.config'] AS agent_config,
  resources_string['agent.client'] AS client,
  attributes_string['toolshelf.mode'] AS mode,
  count() AS runs,
  countIf(has_error) AS failed,
  round(quantile(0.95)(duration_nano) / 1e6) AS p95_ms
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64($start_timestamp_nano)) AND fromUnixTimestamp64Nano(toInt64($end_timestamp_nano))
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND resources_string['service.name'] = 'toolshelf' AND name = 'toolshelf.run'
GROUP BY program, agent_config, client, mode
ORDER BY runs DESC
```

### 12. toolshelf time per phase: Table

```sql
SELECT
  name AS phase,
  count() AS spans,
  round(quantile(0.5)(duration_nano) / 1e6, 1) AS p50_ms,
  round(quantile(0.95)(duration_nano) / 1e6, 1) AS p95_ms,
  round(100 * countIf(has_error) / count(), 1) AS error_pct
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64($start_timestamp_nano)) AND fromUnixTimestamp64Nano(toInt64($end_timestamp_nano))
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND resources_string['service.name'] = 'toolshelf'
GROUP BY phase
ORDER BY p95_ms DESC
```

Expect `toolshelf.check` and `sandbox.prepare` to take milliseconds and
`sandbox.exec` to take nearly everything. toolshelf's own overhead is the
difference between `toolshelf.run` and `sandbox.exec`.

### 13. Blocked commands: Table

```sql
SELECT
  fromUnixTimestamp64Nano(timestamp) AS time,
  resources_string['agent.client'] AS client,
  attributes_string['toolshelf.project'] AS project,
  attributes_string['toolshelf.block_reason'] AS reason,
  attributes_string['toolshelf.command'] AS command
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'toolshelf.blocked'
ORDER BY timestamp DESC
LIMIT 50
```

It's empty until an agent hits the blocklist through `run`. The Claude Code
guard hook's blocks are only in `blocked.jsonl` (`toolshelf_report`).

### API latency by model: Table

```sql
SELECT
  attributes_string['model'] AS model,
  count() AS requests,
  round(quantile(0.5)(attributes_number['duration_ms'])) AS p50_ms,
  round(quantile(0.95)(attributes_number['duration_ms'])) AS p95_ms,
  round(quantile(0.5)(attributes_number['ttft_ms'])) AS p50_ttft_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'api_request'
GROUP BY model
```

TTFT (time to first token) is how long you wait before anything streams.

## 5. Alerts

**Alerts → + New alert → ClickHouse query.** An alert runs its query every
evaluation interval and compares `value` with the threshold.

| Alert | Query | Condition | Evaluate |
|---|---|---|---|
| **Daily cost** | Panel 1's query (cost since midnight IST) | `value` **above** your daily budget, *at least once* | every 5 min, window 5 min |
| **Blocked command** | below | `value` **above 0**, *at least once* | every 5 min, window 1 hour |

```sql
SELECT count() AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN $start_timestamp_nano AND $end_timestamp_nano
  AND ts_bucket_start BETWEEN $start_timestamp - 1800 AND $end_timestamp
  AND attributes_string['event.name'] = 'toolshelf.blocked'
```

**Choosing the budget:** look at panel 2 for a week first. Then set the alert
somewhat above a normal heavy day. The first day here was about $12 across
both configs, but that included long setup sessions.

**Where alerts go:** SigNoz needs a *notification channel* to tell you
anywhere else. Without one, a firing alert shows up on the **Alerts** page (and
**Triggered alerts**) only. Every channel (Slack, email, PagerDuty, a webhook)
sends data off the Mac except a webhook to localhost. A small local receiver
that turns it into a macOS notification is a possible later step.

**SRE habit:** for every alert, write down what you would *do* when it fires.
If the answer is "nothing", it's a dashboard panel, not an alert.

## 6. Reading a trace (flame graphs)

**Traces → filter `service.name = toolshelf` → open a trace.**

- **What the bars mean:** each bar is a span; its width is its duration, and
  bars below a span are its children. The view is a **flame graph** (here
  drawn top-down, sometimes called an icicle chart).
- **Read it top-down:** the widest child is where the time went. Gaps between
  children are time nobody accounted for. In toolshelf, that's the server's
  own work.
- **Errors:** spans in red have an error status. Click one to see its
  attributes: exit code, command, tools.
- **Compare:** open a fast and a slow run of the same program side by side.
  Is the difference all in `sandbox.exec`, which is the program itself, or in
  `docker.network_setup`, the proxy forwarder starting?
- **Claude Code traces** (`service.name = claude-code`): `interaction` is one
  prompt, and its children are `llm_request` and `tool`. Under `tool`,
  `blocked_on_user` is the time spent waiting for **you** to approve.

**Services page:** `toolshelf` shows RED per operation, and that comes for free
from the spans.

## 7. Keep it

When the dashboard looks right, take a copy so a new machine (or a broken
volume) doesn't lose it:
- **Dashboard:** **⋯ → Export JSON**. Save it as
  `DotFiles/config/signoz/dashboards/ai-usage.json`, then import it with
  **Dashboards → Import JSON**.
- **Alerts:** each has its own JSON.
