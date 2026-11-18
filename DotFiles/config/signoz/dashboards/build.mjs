// build.mjs — generate the SigNoz dashboards (schema v6, SigNoz v0.149) from
// the queries in sql/ and the panel lists below.
//
//   node build.mjs          writes ai-usage.json, ai-tools.json, toolshelf.json
//
// Import each file in SigNoz: Dashboards → New dashboard → Import JSON.
// Every sql/*.sql was run against this machine's ClickHouse first. Builder
// panels copy the structure of panels SigNoz itself saved (metrics: the
// user's own "Claude tokens by type"; traces: the built-in AI dashboard).
// Panel ids are derived from dashboard + title, so a rebuilt file keeps them.
// Concepts and the same queries explained: Docs/ObservabilityDashboards.md.

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const sql = (name) => readFileSync(join(HERE, "sql", `${name}.sql`), "utf-8").trim();

function uuid(...parts) {
  const h = createHash("sha1").update(parts.join("\u0000")).digest("hex");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-5${h.slice(13, 16)}-a${h.slice(17, 20)}-${h.slice(20, 32)}`;
}

// --- panel plugins (shapes as SigNoz saves them) -------------------------------

const visualization = { timePreference: "global_time" };
const legend = { customColors: null, mode: "list", position: "bottom" };
const axes = { isLogScale: false, softMax: null, softMin: null };

const plugins = {
  time_series: (unit) => ({
    kind: "signoz/TimeSeriesPanel",
    spec: {
      axes,
      chartAppearance: {
        fillMode: "none",
        lineInterpolation: "spline",
        lineStyle: "solid",
        showPoints: false,
        spanGaps: { fillLessThan: "", fillOnlyBelow: false },
      },
      formatting: { decimalPrecision: "2", unit },
      legend,
      thresholds: null,
      visualization: { ...visualization, fillSpans: false },
    },
  }),
  bar: (unit) => ({
    kind: "signoz/BarChartPanel",
    spec: {
      axes,
      formatting: { decimalPrecision: "2", unit },
      legend,
      thresholds: null,
      visualization: { ...visualization, fillSpans: false, stackedBarChart: true },
    },
  }),
  number: (unit) => ({
    kind: "signoz/NumberPanel",
    spec: { formatting: { decimalPrecision: "2", unit }, thresholds: null, visualization },
  }),
  table: () => ({
    kind: "signoz/TablePanel",
    spec: { formatting: { columnUnits: {}, decimalPrecision: "2" }, thresholds: null, visualization },
  }),
};

// time_series and bar return series; number and table return scalars
const requestKind = { time_series: "time_series", bar: "time_series", number: "scalar", table: "scalar" };

function panel(type, title, description, queries, unit = "") {
  return {
    kind: "Panel",
    spec: {
      display: { name: title, description },
      plugin: plugins[type](unit),
      queries: [
        {
          kind: requestKind[type],
          spec: { plugin: { kind: "signoz/CompositeQuery", spec: { queries } } },
        },
      ],
    },
  };
}

// --- query helpers ---------------------------------------------------------------

/** A ClickHouse SQL query from sql/<file>.sql */
const ch = (file, legendFormat = "") => ({
  type: "clickhouse_sql",
  spec: { name: "A", query: sql(file), disabled: false, ...(legendFormat ? { legend: legendFormat } : {}) },
});

const field = (name, fieldContext = "", fieldDataType = "") => ({ fieldContext, fieldDataType, name, signal: "" });
const resource = (name) => field(name, "resource", "string");
const attribute = (name) => field(name, "attribute", "string");

/** A metrics builder query: Increase over time, Sum across series */
const metric = (metricName, groupBy, legendFormat, name = "A") => ({
  type: "builder_query",
  spec: {
    aggregations: [{ metricName, spaceAggregation: "sum", temporality: "", timeAggregation: "increase" }],
    disabled: false,
    filter: { expression: "" },
    groupBy,
    legend: legendFormat,
    name,
    signal: "metrics",
    source: "",
  },
});

/** A traces builder query with an aggregation expression */
const traces = (expression, filter, { groupBy = [], legendFormat = "", name = "A", disabled = false } = {}) => ({
  type: "builder_query",
  spec: {
    aggregations: [{ expression }],
    disabled,
    filter: { expression: filter },
    ...(groupBy.length ? { groupBy } : {}),
    legend: legendFormat,
    name,
    signal: "traces",
    source: "",
  },
});

const formula = (expression, legendFormat, name = "F1") => ({
  type: "builder_formula",
  spec: { disabled: false, expression, legend: legendFormat, name },
});

const TS_RUNS = "service.name = 'toolshelf' AND name = 'toolshelf.run'";

// --- dashboards -------------------------------------------------------------------
// Each section: [title, [[panel, width], …]]. Width is out of 12; numbers are
// 3 high, everything else 6.

const dashboards = {
  "ai-usage": {
    name: "AI usage: spend, tokens, work",
    description:
      "Claude Code (claude / myclaude) and Codex: cost, tokens, cache, prompts, active time, API latency. " +
      "Cost is Claude Code's own cost_usd; Codex reports tokens only. Days are IST. " +
      "Built by DotFiles/config/signoz/dashboards/build.mjs.",
    tags: ["ai", "claude-code", "codex"],
    sections: [
      ["Spend", [
        [panel("number", "Cost today (IST)", "Claude Code cost since midnight IST (ignores the time range).", [ch("cost_today")], "currencyUSD"), 3],
        [panel("number", "Cost in range", "Claude Code cost in the selected time range.", [ch("cost_range")], "currencyUSD"), 3],
        [panel("number", "Prompts in range", "Prompts typed into Claude Code and Codex.", [ch("prompts_range")], "short"), 3],
        [panel("number", "Sessions in range", "Claude Code sessions plus Codex conversations with at least one prompt.", [ch("sessions_range")], "short"), 3],
        [panel("bar", "Cost per day by config", "One bar per IST day, stacked by agent.config.", [ch("cost_per_day", "{{agent_config}}")], "currencyUSD"), 6],
        [panel("time_series", "Cost over time (metric)", "claude_code.cost.usage: Increase / Sum by agent.config. Trails the events by up to 15 s.",
          [metric("claude_code.cost.usage", [resource("agent.config")], "{{agent.config}}")], "currencyUSD"), 6],
        [panel("table", "Cost by model", "Requests, total and average cost per model and config.", [ch("cost_by_model")]), 6],
        [panel("table", "Cost by repository", "Where the money goes, per repo (vcs.repository.name).", [ch("cost_by_repo")]), 6],
      ]],
      ["Tokens", [
        [panel("time_series", "Claude tokens by type", "claude_code.token.usage: Increase / Sum by type and agent.config.",
          [metric("claude_code.token.usage", [field("type"), resource("agent.config")], "{{type}} · {{agent.config}}")], "short"), 6],
        [panel("time_series", "Codex tokens by type", "codex.turn.token_usage.sum by token_type and model.",
          [metric("codex.turn.token_usage.sum", [field("token_type"), field("model")], "{{token_type}} · {{model}}")], "short"), 6],
        [panel("table", "Prompt cache by config", "cache_hit_pct = cache reads / all input. A drop means something keeps breaking the cache.", [ch("cache_hit")]), 12],
      ]],
      ["Work", [
        [panel("bar", "Prompts per day by source", "claude, myclaude and codex, per IST day: the like-for-like comparison.", [ch("prompts_per_day", "{{source}}")], "short"), 6],
        [panel("time_series", "Active time", "claude_code.active_time.total: user = you typing, cli = Claude working.",
          [metric("claude_code.active_time.total", [resource("agent.config"), field("type")], "{{agent.config}} · {{type}}")], "s"), 6],
        [panel("table", "API latency by model", "p50/p95 request duration and time to first token (ms).", [ch("api_latency")]), 12],
      ]],
    ],
  },

  "ai-tools": {
    name: "AI tools: what agents use",
    description:
      "Tools and MCP calls in Claude Code and Codex, with success rates, durations and approval decisions. " +
      "Built by DotFiles/config/signoz/dashboards/build.mjs.",
    tags: ["ai", "tools", "mcp"],
    sections: [
      ["Usage", [
        [panel("time_series", "Tool calls per hour", "tool_result events by source.", [ch("tool_calls_over_time", "{{source}}")], "short"), 12],
        [panel("table", "Claude Code tools", "bash:<program> and mcp:<server>/<tool> are split out of Bash and mcp_tool.", [ch("claude_tools")]), 12],
        [panel("table", "MCP calls by server", "Across Claude Code and Codex.", [ch("mcp_by_server")]), 6],
        [panel("table", "Codex tools", "Codex logs no output (tool_result.max_bytes = 0).", [ch("codex_tools")]), 6],
        [panel("table", "Tool approvals", "Claude Code tool_decision: accepted or rejected, and by whom (config rule, hook, you).", [ch("tool_decisions")]), 12],
      ]],
    ],
  },

  toolshelf: {
    name: "toolshelf: agent runs",
    description:
      "Every toolshelf run (sandbox or docker) as a trace: what agents run, where time goes, what fails or is blocked. " +
      "Built by DotFiles/config/signoz/dashboards/build.mjs.",
    tags: ["toolshelf", "sre"],
    sections: [
      ["Overview", [
        [panel("number", "Runs", "toolshelf.run spans in range.", [traces("count()", TS_RUNS)], "short"), 3],
        [panel("number", "Failed %", "Runs with an error status (non-zero exit, timeout, blocked).", [
          traces("countIf(has_error = true)", TS_RUNS, { name: "A", disabled: true }),
          traces("count()", TS_RUNS, { name: "B", disabled: true }),
          formula("(A/B)*100", "failed %"),
        ], "percent"), 3],
        [panel("number", "p95 run time", "95th percentile of toolshelf.run duration.", [traces("p95(duration_nano)", TS_RUNS)], "ns"), 3],
        [panel("number", "Blocked", "Blocklist hits through run (the Claude hook's are in blocked.jsonl).", [ch("ts_blocked_count")], "short"), 3],
        [panel("time_series", "Runs by agent", "Count of runs per agent.client.", [
          traces("count()", TS_RUNS, { groupBy: [resource("agent.client"), resource("agent.config")], legendFormat: "{{agent.client}} {{agent.config}}" }),
        ], "short"), 6],
        [panel("time_series", "p95 time per phase", "Hourly p95 of each span (check, prepare, exec, docker.*), in ms.", [ch("ts_phase_p95_over_time", "{{phase}}")], "ms"), 6],
      ]],
      ["Breakdown", [
        [panel("table", "Runs by program", "Grouped by the command's first program.", [ch("ts_runs_by_program")]), 12],
        [panel("table", "Time per phase", "toolshelf's own overhead = toolshelf.run minus sandbox.exec / docker.exec.", [ch("ts_phases")]), 6],
        [panel("table", "Runs by project", "Projects and tool versions agents built.", [ch("ts_runs_by_project")]), 6],
      ]],
      ["Problems", [
        [panel("table", "Failed runs", "Newest first. run_id = the log at ~/.local/state/toolshelf/runs/<run_id>.log.", [ch("ts_failed_runs")]), 12],
        [panel("table", "Blocked commands", "Which rule stopped which command.", [ch("ts_blocked")]), 12],
      ]],
    ],
  },
};

// --- assemble -----------------------------------------------------------------------

for (const [slug, d] of Object.entries(dashboards)) {
  const panels = {};
  const layouts = [];
  for (const [title, row] of d.sections) {
    const items = [];
    let x = 0;
    let y = 0;
    let rowHeight = 0;
    for (const [p, width] of row) {
      const height = p.spec.plugin.kind === "signoz/NumberPanel" ? 3 : 6;
      if (x + width > 12) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      const id = uuid(slug, title, p.spec.display.name);
      panels[id] = p;
      items.push({ content: { $ref: `#/spec/panels/${id}` }, height, width, x, y });
      x += width;
      rowHeight = Math.max(rowHeight, height);
    }
    layouts.push({ kind: "Grid", spec: { display: { title }, items } });
  }
  const out = {
    schemaVersion: "v6",
    name: slug,
    image: "/assets/Icons/eight-ball",
    tags: d.tags,
    spec: {
      display: { name: d.name, description: d.description },
      duration: "",
      layouts,
      panels,
      refreshInterval: "",
      variables: [],
    },
  };
  writeFileSync(join(HERE, `${slug}.json`), JSON.stringify(out, null, 2) + "\n");
  console.log(`${slug}.json: ${Object.keys(panels).length} panels in ${layouts.length} sections`);
}
