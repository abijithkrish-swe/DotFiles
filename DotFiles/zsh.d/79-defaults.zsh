# 79) defaults at login
# Default and autoload versions live in the components manifest
# ($COMPONENTS_MANIFEST): `default` = used when no version is given (exported as
# DEFAULT_<TOOL> by 70-components-core), `autoload` = activated below in
# interactive shells. Change them there, not here.

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
      unset _cm_t
    fi
  ;;
esac

# ---------------------------------------------------------------------
# 80) completions
# ---------------------------------------------------------------------
