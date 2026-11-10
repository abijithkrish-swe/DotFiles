# --- components help module --------------------------------------------------
_devhelp_components() {
cat <<'EOF2'
Components — Approved Tool Versions
===================================

Everything under ~/Components is used ONLY if it is listed in the manifest:
  ~/.config/components/components.conf     (deployed copy)
  DotFiles/config/components/components.conf  (source of truth, edit this)
use_<tool>, toolup, login defaults, tab completion and the toolshelf MCP
server (AI agents) all read it. Edits are picked up automatically.

Commands
--------
components_check        # every tool: approved versions, flags, broken/unlisted
components_status       # what is active in this shell (alias: status_components)
components_reload       # force re-read of the manifest (rarely needed)
<tool>_list             # one tool, e.g. jdk_list, node_list, mysql_list
use_<tool> [ver]|off    # activate; no ver = default; prefix ok (26 → 26.0.2)

Version matching
----------------
exact, or a unique prefix on a segment boundary:
  use_jdk 26 → 26.0.2    use_maven 3.9 → 3.9.12    use_node 22 → 22.21.1
  use_node 2 → rejected (ambiguous / not approved, never guessed)

Manifest lines
--------------
@tool jdk  dir=JDK  root=Contents/Home|.  check=java  home=JAVA_HOME
jdk   17
jdk   11       default autoload
mysql 8.0.43   default onpath

Flags
-----
default    used when no version is given (exported as DEFAULT_<TOOL>)
autoload   activated at interactive login (PATH + env vars + status)
onpath     only its bin dir on PATH at login (e.g. mysql client for remote
           hosts); not activated, nothing started. Exclusive with autoload.
docker=    pinned Linux image (image@sha256:...) for sandboxed runs

Add / update a version
----------------------
1. unpack to ~/Components/<Dir>/<version>/
2. add "<tool> <version>" to DotFiles/config/components/components.conf
3. install_copy.sh deploy   then   components_check

Per-project: .toolsrc + toolup
------------------------------
JDK=17  MAVEN=3.9  NODE=22  RUST=  ...   (empty value = skip)
toolup                  # resets PATH, applies .toolsrc; returns 1 on failures

AI agents
---------
Agents use the toolshelf MCP (list_components, get_component_env), not use_*.
Design & runbooks: Docs/AgentComponents.md
EOF2
}

_devhelp_register "components" _devhelp_components
