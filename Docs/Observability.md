# Observability: AI usage in self-hosted SigNoz

What gets measured, where it goes, and **why each setting is what it is**, so
it can be changed later on purpose. Everything stays on this Mac.

- **Stack:** SigNoz on Colima (`obs_start`, `devhelp observability`).
- **UI:** `http://localhost:18080`.
- **OTLP:** gRPC `127.0.0.1:4317`, HTTP `127.0.0.1:4318`.

## Goals

1. **AI usage for real decisions:** how much work AI actually does, and which
   agents and tools earn their subscription: cost, tokens, sessions, active
   time, tools used.
2. **Keep `claude` and `myclaude` apart.** They used to mix in shared logs.
3. **Learn observability and SRE** on real data: traces and flame graphs, RED
   metrics, dashboards, alerts, ClickHouse SQL.

## Sources

| Source | Status | How |
|---|---|---|
| Claude Code (`claude`, `myclaude`, the Claude app's Code tab) | ✅ | `env` block in `DotFiles/config/agents/claude-settings.json`, merged by `install_copy.sh agents` |
| Codex (CLI, Codex in ChatGPT) | ✅ | `[otel]` section in `~/.codex/config.toml`, pasted by hand (below) |
| toolshelf `run` | ✅ | built in (toolshelf-mcp `src/telemetry.ts`): a trace per run, a `toolshelf.blocked` event per blocklist hit. Default endpoint `http://127.0.0.1:4318`; `TOOLSHELF_OTLP_ENDPOINT=off` disables it. Details in the toolshelf README → Telemetry |

## Claude Code settings

They're set in `DotFiles/config/agents/claude-settings.json` → `env`, then
`sh install_copy.sh agents` merges them into **both** configs' `settings.json`.
Restart sessions afterwards. Settings apply to every session.

| Setting | Value | Why |
|---|---|---|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` | The master switch; nothing is exported without it. |
| `OTEL_METRICS_EXPORTER` | `otlp` | Metrics: cost, tokens, sessions, active time, lines changed, commits/PRs, edit decisions. |
| `OTEL_LOGS_EXPORTER` | `otlp` | Events: every API request (model, cost, tokens, duration), tool result (tool, duration, success), error, refusal, permission decision. The richest data for "which tools do I use". |
| `OTEL_TRACES_EXPORTER` | `otlp` | Traces: one span tree per prompt, interaction → LLM request → tool → blocked-on-you / execution. This is where flame graphs come from. |
| `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA` | `1` | Traces are beta in Claude Code and need this. |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | Port 4317 is SigNoz's gRPC receiver. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://127.0.0.1:4317` | **`127.0.0.1`, not `localhost`:** the proxy helper's `no_proxy` lists `127.0.0.1` but not `localhost`, so `localhost` would go into the zero-trust proxy and be lost. |
| `OTEL_RESOURCE_ATTRIBUTES` | `agent.config=claude` / `agent.config=myclaude` | The merge fills in `{agent_config}` per config dir, so every metric, event and span says which config produced it. Filter or group by `agent.config` in SigNoz. |
| `OTEL_LOG_TOOL_DETAILS` | `1` | Adds Bash commands, MCP server/tool names and skill names to tool events, for "which tools and MCPs do I really use". Commands are locally stored data; see the privacy notes. |
| `OTEL_METRICS_INCLUDE_VERSION` | `true` | `app.version` on metrics: compare behaviour and cost across Claude Code versions. |
| `OTEL_METRICS_INCLUDE_ENTRYPOINT` | `true` | `app.entrypoint`: the CLI vs the desktop app vs IDE. |
| `OTEL_METRICS_INCLUDE_REPOSITORY` | `true` | The repo name/owner on metrics: cost and work **per project**. |
| `OTEL_METRICS_EXPORT_INTERVAL` | `15000` | Metrics every 15 s instead of 60 s, so dashboards react while you learn. Raise it to `60000` to cut volume. |

Left at their defaults, all fine: `session.id` and account ids on metrics
(per-session drill-down), delta temporality, and the logs and traces export
intervals (5 s).

### Not set, on purpose: turn on if needed

| Setting | What it would add | Why it's off |
|---|---|---|
| `OTEL_LOG_USER_PROMPTS=1` (and `OTEL_LOG_ASSISTANT_RESPONSES=1`, which falls back to it) | The full **text** of every prompt and every reply, in ClickHouse. | Anything pasted into a prompt, secrets included, would be stored in another place, readable through SigNoz. The session transcripts in `~/.claude/projects/` already hold the text. Lengths are recorded anyway (`prompt_length`, `response_length`). Turn on for prompt-quality analysis, and think about retention first. |
| `OTEL_LOG_RAW_API_BODIES=1` (or `file:<dir>`) | Every API request and response body: the **whole conversation history** each time. | Very large, since each request repeats the conversation, and it's the same secrets concern, multiplied. Only for debugging the API itself. |

To change any of these, edit `claude-settings.json` → `env`, run
`sh install_copy.sh agents` (it reports each changed value), and restart the
sessions. To turn telemetry off entirely, set `CLAUDE_CODE_ENABLE_TELEMETRY`
to `"0"`.

## Codex settings

Codex reads OTel settings only from its own `~/.codex/config.toml`, and agents
can't edit that file (deny rules and the blocklist), so you **paste this in by
hand**, at the end of the file. Then restart the ChatGPT app (and any `codex`
CLI sessions):

```toml
[otel]
environment = "local"
log_user_prompt = false
tool_result = { max_bytes = 0 }
exporter         = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
trace_exporter   = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
metrics_exporter = { otlp-grpc = { endpoint = "http://127.0.0.1:4317" } }
```

| Setting | Value | Why |
|---|---|---|
| `exporter` | OTLP gRPC | Events: `codex.conversation_starts`, `codex.api_request`, `codex.sse_event`, `codex.tool_decision`, `codex.tool_result`, `codex.user_prompt`. |
| `trace_exporter` | OTLP gRPC | Spans per turn and tool call, for flame graphs. |
| `metrics_exporter` | OTLP gRPC | `codex.turn.token_usage.*`, `codex.turn.cost_microusd`, `codex.turn.e2e_duration_ms`, `codex.turn.ttft.duration_ms`, `codex.tool.call(.duration_ms)`, `codex.api_request(.duration_ms)`. Codex can also send metrics to `statsig` (OpenAI's service). Pointing this at SigNoz keeps them here. |
| endpoint | `http://127.0.0.1:4317` | The same `127.0.0.1` reason as for Claude Code. |
| `environment` | `local` | Codex adds it to every event; useful only to tell machines apart. |
| `log_user_prompt` | `false` (the default) | Written out so the choice is visible. `true` would store prompt text; the reasons it's off are the same as for Claude Code's `OTEL_LOG_USER_PROMPTS`. |
| `tool_result.max_bytes` | `0` | **By default Codex logs the first ~2 KB of every tool's output** (`output` on `codex.tool_result`): file contents, command output, MCP replies. The first test run stored lines of work code. `0` keeps the event (tool, duration, success, arguments) without the output. This is stricter than Claude Code, which never logs tool output. Raise it only for debugging. |

**What Codex doesn't report:** there's no cost on a ChatGPT subscription
(`codex.turn.cost_microusd` never appeared). Tokens per model are there
(`codex.turn.token_usage`, `token_type` input/cached_input/output/
reasoning_output). Usage is measured in tokens and turns, not dollars.

**Trace volume:** Codex traces its internals too (`fs.get_metadata`,
`fs.read_file`, auth, MCP refresh): one prompt made ~11,500 spans in 540
traces. That's still only ~1 MB. For flame graphs, filter on the
turn and tool spans. If it grows too much, set `trace_exporter = "none"`; the
events and metrics cover usage.

Left at their defaults, on purpose: `log_agent_responses`, `log_sse_deltas`
and `log_guardian_assessments` (reply text and streaming chunks: large, and the
same privacy concern), plus `span_attributes` and `tracestate`.

**Telling the sources apart:** Codex has one config, so it needs no
`agent.config` label. Its `service.name` says which surface ran it:
`codex_exec` for `codex exec`, and others for the interactive CLI and the
ChatGPT app. Claude Code uses `service.name=claude-code`, plus `agent.config`.

Checked against codex-cli 0.167.0 (the build bundled in the ChatGPT app):
- The block above loads (`codex mcp list` with it in a scratch `CODEX_HOME`),
  and a bad exporter name fails with "unknown variant".
- A `codex exec` run sent a `codex_exec` event to SigNoz.

To turn Codex telemetry off, delete the `[otel]` section, or set the three
exporters to `"none"`.

## What you'll find in SigNoz

- **Metrics** (Dashboards → New panel):
  - `claude_code.cost.usage` (USD) and `claude_code.token.usage` (`type`:
    input/output/cacheRead/cacheCreation), by `model`, `agent.config` and repo;
  - `claude_code.session.count`, `claude_code.active_time.total`
    (`type` user/cli);
  - `claude_code.lines_of_code.count`, `claude_code.commit.count`,
    `claude_code.pull_request.count`;
  - `claude_code.code_edit_tool.decision`: accept/reject per tool and
    language.
- **Logs / events** (Logs explorer, filter `event.name`):
  - `claude_code.api_request`: cost, tokens and latency per call;
  - `claude_code.tool_result`: tool, duration, success, plus the command or
    MCP name;
  - `claude_code.tool_decision`: what you approved or rejected;
  - `claude_code.api_error`, `claude_code.api_refusal`;
  - `claude_code.user_prompt`: length only.
- **Traces** (Traces explorer → a trace → flame graph):
  - `claude_code.interaction` per prompt, with `claude_code.llm_request` and
    `claude_code.tool` children;
  - `tool.blocked_on_user`, the time waiting for your approval, is visible
    separately from `tool.execution`.

- **toolshelf** (`service.name=toolshelf`):
  - **Traces:** `toolshelf.run` contains `toolshelf.check`, then
    `sandbox.prepare` and `sandbox.exec` (or the `docker.*` phases). Group by
    `agent.client` (which app ran it), `agent.config`, `toolshelf.command.name`
    (mvn, pnpm …), `toolshelf.project` or `process.exit.code`.
  - **RED metrics for free:** SigNoz's collector turns spans into
    `signoz_calls_total` and `signoz_latency` per operation. That gives a rate,
    errors and duration for every phase without any metrics code in toolshelf.
  - **Logs:** `toolshelf.blocked`, which rule stopped which command, linked to
    the run's trace. The guard hook's blocks (Claude Code's own Bash) are
    still only in `blocked.jsonl`, so `toolshelf_report` shows both.

## Notes

- **When SigNoz isn't running,** exports fail quietly and Claude Code works
  normally; that period's data is lost.
- **Volume** is small: metrics every 15 s, plus a handful of events and spans
  per prompt.
- **Privacy:** nothing leaves the Mac. SigNoz's own stats reporter and
  analytics are off (see the casting). The data sits in the Docker volumes
  `signoz-*`. Bash commands go into tool events (`OTEL_LOG_TOOL_DETAILS`), so a
  secret typed into a command line would be stored too, which is one more
  reason never to put secrets in commands.
- **Source of truth for these names:**
  [Claude Code monitoring docs](https://code.claude.com/docs/en/monitoring-usage),
  checked 2026-11-13.
