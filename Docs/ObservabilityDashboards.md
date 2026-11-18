# Observability: building the AI-usage dashboard and alerts

A hands-on guide: you build one dashboard and two alerts in SigNoz
(`http://localhost:18080`) and learn the concepts on the way. Every SQL query
here was tested against this machine's data on 2026-11-13. What is collected,
and why: `Observability.md`.

**Written for SigNoz v0.149** (dashboard schema v6, Query Builder v5). The
labels here are taken from that version's UI code, not from older docs: older
versions say "Value" for **Number**, and use different aggregation fields. If
a label still doesn't match, describe what you see and fix this file.

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

- **Query Builder** (tab *Query Builder*): SigNoz writes the SQL. It has two
  styles, depending on the signal:
  - **Metrics:** pick a metric (*Search metric name*), then *Temporal
    Aggregation* and *Spatial Aggregation* (below).
  - **Logs and traces:** you type two **expressions**:
    - a *Filter*, e.g. `attribute.event.name = 'api_request' AND agent.config = 'claude'`;
    - an aggregation, e.g. `sum(cost_usd)`, `count()`, `p95(duration_ms)`,
      `count_distinct(session.id)`.

    Then *Group By*, *Order By*, *Limit*, *Having* (e.g. `count() > 10`) and
    *Legend format*.

  Use the builder for most panels: it's faster, and its expression language is
  the one alerts and the explorers use too.
- **ClickHouse Query** (tab *ClickHouse Query*): full control: computed
  columns, conditional grouping, percentages, time zones. Use it when the
  builder can't express something (marked **SQL only** below). It is also the
  skill that transfers to other stacks.

**Can't aggregate a field?** The builder can only `sum`/`p95` **number**
attributes. `cost_usd`, `input_tokens` and Claude's API `duration_ms` are
numbers. Claude Code's and Codex's *tool* `duration_ms` and `success` are sent
as **strings**, so those panels need SQL (`toFloat64OrZero`).

**Keys that start with a context word:** a filter key can begin with a
*context*: `resource.`, `attribute.`, `span.`, `log.`, `event.`, `scope.`,
`body.`, `metric.` or `trace.`. So `event.name` is read as "the key `name` in
context `event`", and fails with **key `name` not found**. Spell out the
context when a key starts with one of those words: `attribute.event.name`.
On traces, a span's own name isn't a filterable key either. toolshelf panels
filter on `toolshelf.mode EXISTS` instead, which only `toolshelf.run` spans
carry.

### Metric vocabulary (the Query Builder asks for these)

- **Counter (Sum, monotonic):** only goes up, e.g. tokens and cost. Claude
  Code and Codex both send **delta** counters: each export carries only what
  happened since the last export.
- **Temporal Aggregation** (time aggregation): how one series is rolled up
  within each time step. For counters the choices are `Rate` and `Increase`.
  `Increase` means how much it grew in that step (use it for cost and tokens).
  `Rate` means per second (use it for throughput).
- **Spatial Aggregation** (space aggregation): how series are combined across
  labels (`Sum`, `Avg`, `Min`, `Max`, `P50` … `P99`). `Sum` adds `type=input`
  and `type=output` together unless you **Group By** `type`.
- **Step:** "Set the time interval for aggregation", the width of each point
  or bar. Set it to 1 day (86400 s) for per-day bars.
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
- `{{.start_timestamp}}` / `{{.end_timestamp}}` in seconds;
- `{{.start_timestamp_ms}}` in milliseconds;
- `{{.start_timestamp_nano}}` / `{{.end_timestamp_nano}}` in nanoseconds.

This is the form the v0.149 editor's own example uses. SigNoz's backend also
uses `$start_timestamp_nano` internally, so the `$` form probably works too,
but this guide sticks to the documented one.

- **Logs** have `timestamp` in nanoseconds (a number).
- **Traces** have a DateTime64, so the trace queries wrap the variable:
  `fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}}))`.
- **`ts_bucket_start`** is the partition key (seconds). Always filter it too,
  so ClickHouse skips old data (the `- 1800` covers the 30-minute bucket).

Time-series SQL panels must return a time column named **`ts`**, a number
named **`value`**, and optional label columns (one line per label value).

**Days are IST:** ClickHouse runs in UTC, so day buckets use
`toStartOfDay(…, 'Asia/Kolkata')`. Otherwise "today" would start at 05:30.

## Ready-made: the three dashboards

`DotFiles/config/signoz/dashboards/` holds three generated dashboards, built
from the tested queries in `sql/` by `build.mjs`:
- `ai-usage.json`: spend, tokens, cache, prompts, active time, API latency.
- `ai-tools.json`: Claude Code and Codex tools, MCP calls, approvals.
- `toolshelf.json`: runs, failures, time per phase, blocked commands.

Import each one: **Dashboards → New dashboard → Import JSON → Upload JSON
file**. To change a panel, edit `build.mjs` or a `.sql` file, run `node
build.mjs`, and re-import. The rest of this guide explains how those panels
work, so you can build or change your own.

## 2. Start with the built-in AI dashboard

Your SigNoz already has **Dashboards → AI Observability Overview**, about 30
panels:
- **Cost:** total, over time, per call and per trace, by provider and service.
- **Tokens and cache:** token usage, the prompt-cache hit ratio.
- **Latency and errors:** LLM latency and TTFT p95, error rate by model.
- **Tools:** top tools, tool call rate and errors.

It reads the OpenTelemetry **`gen_ai.*`** span fields
(`gen_ai.request.model`, `gen_ai.usage.input_tokens` …), and both Claude Code
(`claude_code.llm_request` spans) and Codex send those. **Open it first:** set
the time range to *Last 7 days* and use its variable bar (`service_name`, model,
provider). It's also a good example to learn from: open any panel's editor to
see how a v5 query is put together.

What it **can't** show, and why we still build our own:
- **claude vs myclaude:** it has no `agent.config` variable.
- **Claude Code's own cost:** it uses `cost_usd` from Claude Code's
  `api_request` events, the exact figure Claude Code reports.
- **Tools by real name:** `mcp:toolshelf/run`, `bash:git`.
- **toolshelf, and prompts per day across Claude and Codex.**

## 3. What we're building

One dashboard, **AI usage**, in five rows:

| Row | Panels (visualization) | Question it answers |
|---|---|---|
| **Spend** | 1 Cost today (Number), 2 Cost per day by config (Bar Chart), 3 Cost by model (Table) | Is the subscription worth it? Does `myclaude` or `claude` cost more? |
| **Tokens** | 4 Claude tokens by type (Time Series), 5 Cache hit % (Table), 6 Codex tokens (Time Series) | Where do tokens go? Is caching working? |
| **Work** | 7 Prompts per day by source (Bar Chart), 8 Active time (Time Series) | How much do I actually use each agent? |
| **Tools** | 9 Claude Code top tools, 10 Codex top tools (Tables) | Which tools and MCPs do I really use, and which fail? |
| **toolshelf** | 11 Runs by program, 12 Time per phase (Tables), 13 Blocked commands (List) | What do agents run, what fails, what gets blocked? |
| | 14 API latency by model (Table) | Is the model slow, or my tools? |

Plus two alerts: **daily cost over a threshold**, and **any blocked command**.

## 4. The editor, step by step

**The flow in v0.149:**
1. **Dashboards → New dashboard → Create dashboard.** Name it `AI usage`.
2. **New panel.** A side panel asks you to *Pick a visualization*: **Time
   Series**, **Bar Chart**, **Area Chart**, **Number**, **Table**, **List**,
   **Pie Chart**, **Histogram**, **Heatmap**, **Scatter Plot** or **Text**.
   You can change the type later (*Panel type*).
3. The editor has query tabs: **Query Builder**, **ClickHouse Query** and
   **PromQL**. In the builder, choose the signal: **Metrics**, **Logs** or
   **Traces**.
4. Write the query, then **Run Query** to preview it.
5. Set the panel's name, and in its settings the **Unit** (*Select unit*),
   **Decimal places**, **Legend** / *Legend position*, and **Stacked** for
   time series.
6. **Save changes.** Set the dashboard time range at the top right (*Last 7
   days*).

### Panel 4, Claude tokens by type (Metrics). You built this one.

| Field | Value |
|---|---|
| Visualization | Time Series |
| Signal | Metrics |
| Metric (*Search metric name*) | `claude_code.token.usage` |
| Temporal Aggregation | `Increase` |
| Spatial Aggregation | `Sum` |
| Group By | `type`, `agent.config` |
| Legend format | `{{type}} · {{agent.config}}` |
| Unit | `tokens` (you picked this; it's right) |

Your saved panel has exactly this. The legend SigNoz filled in
(`type = {{type}}, agent.config = {{agent.config}}`) works; the shorter one
is just easier to read. Turning on **Stacked** shows the total as the top
line.

**What to notice:** `cacheRead` dwarfs everything (cached input is cheap, so
that's good). `output` is small but is priced highest per token.

**Panel 6, Codex tokens:** the same recipe, with metric
`codex.turn.token_usage.sum`, Group By `token_type`, `model`, and legend
`{{token_type}} · {{model}}`.

**Panel 8, active time:** metric `claude_code.active_time.total`, Increase /
Sum, Group By `agent.config`, `type` (`user` = you typing, `cli` = Claude
working). Unit: seconds.

### Logs panels in the builder (expressions)

Signal **Logs**. The *Filter* picks the events, and the aggregation says what
to compute.

| # | Visualization | Filter | Aggregation(s) | Group By | Notes |
|---|---|---|---|---|---|
| 2 | Bar Chart | `attribute.event.name = 'api_request'` | `sum(cost_usd)` | `agent.config` | Unit USD. Step 86400 s for one bar per day. **The days are UTC** (they start at 05:30 IST); for IST days use the SQL below. |
| 3 | Table | `attribute.event.name = 'api_request'` | `count()`, `sum(cost_usd)`, `avg(cost_usd)` (*Add a second aggregation*) | `model`, `agent.config` | Order By `sum(cost_usd)` desc. |
| 7 | Bar Chart | `attribute.event.name IN ('user_prompt', 'codex.user_prompt')` | `count()` | `service.name`, `agent.config` | Codex has no `agent.config`, so its bars show it empty. Step 86400 s. |
| 13 | **List** | `attribute.event.name = 'toolshelf.blocked'` | none (a List shows rows) | none | Add the columns `agent.client`, `toolshelf.project`, `toolshelf.block_reason` and `toolshelf.command`. |
| 14 | Table | `attribute.event.name = 'api_request'` | `p50(duration_ms)`, `p95(duration_ms)`, `p50(ttft_ms)` | `model` | Unit ms. |

**Try it:** build panel 1 with the builder (Signal **Metrics**,
`claude_code.cost.usage`, Increase / Sum, visualization **Number**, unit USD)
*and* with the SQL below. Then compare:
- **Closed sessions match exactly:** myclaude was $6.797 both ways.
- **A running session's metric trails its events:** $5.44 against $5.66 during
  this session. Metrics are exported every 15 s, events every 5 s.

**Two pipelines for the same number** is a good lesson in why you pick one
source of truth per panel.

### Traces panels in the builder

Signal **Traces**:

| # | Visualization | Filter | Aggregation(s) | Group By |
|---|---|---|---|---|
| 11 | Table | `service.name = 'toolshelf' AND toolshelf.mode EXISTS` | `count()`, `p95(duration_nano)` | `toolshelf.command.name`, `agent.config`, `agent.client` |
| 12 | Table | `service.name = 'toolshelf'` | `count()`, `p50(duration_nano)`, `p95(duration_nano)` | `name` |

For error counts, add a second query with the filter extended by
`AND has_error = true`, or use the SQL versions below, which compute
`failed` and `error_pct` in one table.

## 5. The SQL panels

**Builder first, SQL when it's needed.** Each panel below also works as a
**ClickHouse Query**: *New panel → the visualization → tab ClickHouse Query →
paste → Run Query*. Use the SQL for:
- **SQL only:** 1 (since midnight IST), 5 (a percentage), 9 (real tool names),
  10 (string durations);
- **SQL is better:** 2 and 7 (IST days), 11 and 12 (error counts in the same
  table).

### 1. Cost today: Number, unit USD (SQL only)

```sql
SELECT sum(attributes_number['cost_usd']) AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp >= toUnixTimestamp(toStartOfDay(now(), 'Asia/Kolkata')) * 1000000000
  AND ts_bucket_start >= toUnixTimestamp(toStartOfDay(now(), 'Asia/Kolkata')) - 1800
  AND attributes_string['event.name'] = 'api_request'
```

Ignores the dashboard time range on purpose: always "since midnight IST".

### 2. Cost per day by config: Bar Chart, unit USD (IST days)

```sql
SELECT
  toStartOfDay(fromUnixTimestamp64Nano(timestamp), 'Asia/Kolkata') AS ts,
  resources_string['agent.config'] AS agent_config,
  sum(attributes_number['cost_usd']) AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
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
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY model, agent_config
ORDER BY cost_usd DESC
```

### 5. Cache hit %: Table (SQL only)

```sql
SELECT
  resources_string['agent.config'] AS agent_config,
  sum(attributes_number['cache_read_tokens']) AS cache_read,
  sum(attributes_number['input_tokens'] + attributes_number['cache_creation_tokens']) AS uncached_input,
  round(100 * cache_read / nullIf(cache_read + uncached_input, 0), 1) AS cache_hit_pct
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY agent_config
```

The first run showed 98.6 % (claude) and 89.1 % (myclaude). A sudden drop
means something is breaking the prompt cache: a changed system prompt, MCP
tools reconnecting, or a compaction.

### 7. Prompts per day by source: Bar Chart (IST days)

```sql
SELECT
  toStartOfDay(fromUnixTimestamp64Nano(timestamp), 'Asia/Kolkata') AS ts,
  if(resources_string['service.name'] = 'claude-code', resources_string['agent.config'], 'codex') AS source,
  count() AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] IN ('user_prompt', 'codex.user_prompt')
GROUP BY ts, source
ORDER BY ts
```

The one panel that compares Claude and Codex like for like (Codex has no cost).

### 9. Claude Code top tools: Table (SQL only)

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
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
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

### 10. Codex top tools: Table (SQL only: durations are strings)

```sql
SELECT
  attributes_string['tool_name'] AS tool,
  attributes_string['mcp_server'] AS mcp_server,
  count() AS calls,
  round(100 * countIf(attributes_string['success'] = 'true') / count(), 1) AS success_pct,
  round(quantile(0.95)(toFloat64OrZero(attributes_string['duration_ms']))) AS p95_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
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
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}})) AND fromUnixTimestamp64Nano(toInt64({{.end_timestamp_nano}}))
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
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
WHERE timestamp BETWEEN fromUnixTimestamp64Nano(toInt64({{.start_timestamp_nano}})) AND fromUnixTimestamp64Nano(toInt64({{.end_timestamp_nano}}))
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND resources_string['service.name'] = 'toolshelf'
GROUP BY phase
ORDER BY p95_ms DESC
```

Expect `toolshelf.check` and `sandbox.prepare` to take milliseconds and
`sandbox.exec` to take nearly everything. toolshelf's own overhead is the
difference between `toolshelf.run` and `sandbox.exec`.

### 13. Blocked commands: Table (or the List panel above)

```sql
SELECT
  fromUnixTimestamp64Nano(timestamp) AS time,
  resources_string['agent.client'] AS client,
  attributes_string['toolshelf.project'] AS project,
  attributes_string['toolshelf.block_reason'] AS reason,
  attributes_string['toolshelf.command'] AS command
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'toolshelf.blocked'
ORDER BY timestamp DESC
LIMIT 50
```

It's empty until an agent hits the blocklist through `run`. The Claude Code
guard hook's blocks are only in `blocked.jsonl` (`toolshelf_report`).

### 14. API latency by model: Table

```sql
SELECT
  attributes_string['model'] AS model,
  count() AS requests,
  round(quantile(0.5)(attributes_number['duration_ms'])) AS p50_ms,
  round(quantile(0.95)(attributes_number['duration_ms'])) AS p95_ms,
  round(quantile(0.5)(attributes_number['ttft_ms'])) AS p50_ttft_ms
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'api_request'
GROUP BY model
```

TTFT (time to first token) is how long you wait before anything streams.

## 6. Alerts

**Alerts → Alert Rules → New alert.** *Select Alert Type*: **Logs Based
Alert** for both alerts here. The other types are Metrics Based, Traces Based,
Anomaly Detection and Exceptions.

The query part is the same builder as in panels (*Filter* plus aggregation).
Then the condition reads as a sentence:

> *Send a notification when* **A** *is* **ABOVE** the threshold **AT LEAST
> ONCE** during the evaluation window.

- **The operator:** ABOVE or BELOW.
- **The match type:**
  - AT LEAST ONCE: any point crosses.
  - ALL THE TIME: every point crosses.
  - ON AVERAGE.
  - IN TOTAL: the window's sum.
  - LAST: the latest point.
- **The evaluation window:**
  - **Rolling:** the last 5 min, 1 hour, 24 hours …
  - **Cumulative:** *Current hour*, *Current day starting from 00:00
    (timezone)*, or *Current month*.

  Cumulative is exactly what a daily budget needs, with no SQL.

| Alert | Filter | Aggregation | Condition | Evaluation window |
|---|---|---|---|---|
| **Daily cost** | `attribute.event.name = 'api_request'` | `sum(cost_usd)` | ABOVE your budget, **IN TOTAL** | **Cumulative → Current day**, from 00:00, timezone **Asia/Kolkata** |
| **Blocked command** | `attribute.event.name = 'toolshelf.blocked'` | `count()` | ABOVE `0`, AT LEAST ONCE | Rolling, last 1 hour |
| **Rate limit hit** | `attribute.event.name = 'api_error' AND error CONTAINS 'rate limit'` | `count()`, Group By `agent.config` | ABOVE `0`, AT LEAST ONCE | Rolling, last 15 minutes |
| **toolshelf failures** (*Traces Based Alert*) | `service.name = 'toolshelf' AND toolshelf.mode EXISTS AND has_error = true` | `count()`, Group By `agent.client` | ABOVE `5`, IN TOTAL | Rolling, last 1 hour |

Add Group By `agent.config` to the cost alert to get one alert per config. A
group-by also lets SigNoz group the notifications.

**The SQL way:** a Logs Based Alert also has a *ClickHouse Query* tab, and the
query must return a `value` column. Panel 1's SQL (cost since midnight IST)
works as is. This is the blocked-commands one:

```sql
SELECT count() AS value
FROM signoz_logs.distributed_logs_v2
WHERE timestamp BETWEEN {{.start_timestamp_nano}} AND {{.end_timestamp_nano}}
  AND ts_bucket_start BETWEEN {{.start_timestamp}} - 1800 AND {{.end_timestamp}}
  AND attributes_string['event.name'] = 'toolshelf.blocked'
```

**Choosing the budget:** look at panel 2 for a week first. Then set the alert
somewhat above a normal heavy day. The first day here was about $12 across
both configs, but that included long setup sessions.

**Where alerts go:** SigNoz needs a *notification channel* (*Select
notification channels*) to tell you anywhere else. Without one, a firing alert
shows up only under **Alerts → Triggered Alerts**. Every channel (Slack, email, PagerDuty, a webhook)
sends data off the Mac except a webhook to localhost. A small local receiver
that turns it into a macOS notification is a possible later step.

**SRE habit:** for every alert, write down what you would *do* when it fires.
If the answer is "nothing", it's a dashboard panel, not an alert.

## 7. Reading a trace (flame graphs)

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

## 8. Keep it

When the dashboard looks right, take a copy so a new machine (or a broken
volume) doesn't lose it:
- **Saving:** dashboards are stored as JSON in SigNoz's Postgres (table
  `dashboard`, column `data`, schema v6). An agent can read it out with
  `docker exec signoz-metastore-postgres-0 psql … -c "select data from
  dashboard"` and save it as `DotFiles/config/signoz/dashboards/ai-usage.json`,
  so you don't need to find the UI's export menu.
- **Restoring:** **New dashboard → Import JSON** (next to *From a template*).
- **Alerts:** these are rules in the same database. Their definitions are
  short; rebuild them from section 6.
