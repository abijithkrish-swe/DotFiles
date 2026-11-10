# 79) defaults at login
# Default and autoload versions live in the components manifest
# ($COMPONENTS_MANIFEST): `default` = used when no version is given (exported as
# DEFAULT_<TOOL> by 70-components-core), `autoload` = activated below in
# interactive shells, `onpath` = only its bin dir put on PATH (no activation).
# Change them there, not here.

export COLIMA_HOME="$HOME/.config/colima"
# XDG for Docker
export DOCKER_CONFIG="$HOME/.config/docker"   # -> ~/.config/docker

# Apply only for interactive shells
case $- in
  *i*)
    if (( $+functions[components_ensure_loaded] )) && components_ensure_loaded; then
      for _cm_t in "${CM_TOOLS[@]}"; do
        [[ -n "${CM_AUTOLOAD[$_cm_t]}" ]] || continue
        if (( $+functions[use_$_cm_t] )); then
          "use_$_cm_t" "${CM_AUTOLOAD[$_cm_t]}" >/dev/null 2>&1 \
            || echo "Note: $_cm_t ${CM_AUTOLOAD[$_cm_t]} (autoload) could not be activated — run: use_$_cm_t ${CM_AUTOLOAD[$_cm_t]}"
        else
          echo "Note: autoload for $_cm_t, but no use_$_cm_t function is defined"
        fi
      done
      # onpath: binaries reachable (e.g. mysql client for remote hosts) without
      # activating the tool — no env vars, not shown in components_status.
      for _cm_t in "${CM_TOOLS[@]}"; do
        [[ -n "${CM_ONPATH[$_cm_t]}" ]] || continue
        if components_resolve "$_cm_t" "${CM_ONPATH[$_cm_t]}" 2>/dev/null; then
          component_switch_path "_CM_ONPATH_${(U)_cm_t}_BIN" "$CM_BIN_DIR"
        else
          echo "Note: $_cm_t ${CM_ONPATH[$_cm_t]} (onpath) not usable — run: components_check"
        fi
      done
      unset _cm_t
    fi
  ;;
esac

# ---------------------------------------------------------------------
# 80) completions
# ---------------------------------------------------------------------
