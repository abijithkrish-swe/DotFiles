# 71) JDK helpers

# Resolve a JDK home under ~/Components/JDK/<ver>
_jdk_home() {
  local root="$COMPONENTS/JDK/$1"
  if [ -d "$root/Contents/Home" ]; then
    echo "$root/Contents/Home"; return 0
  fi
  if [ -d "$root" ]; then
    echo "$root"; return 0
  fi
  return 1
}

# List available JDKs
jdk_list() {
  if [ -d "$COMPONENTS/JDK" ]; then
    echo "Available JDKs in $COMPONENTS/JDK:"
    ls -1 "$COMPONENTS/JDK"
  else
    echo "No JDKs found in $COMPONENTS/JDK"
  fi
}

# Switch JDK version
# use_jdk 11 -> sets JAVA_HOME and prepends bin to PATH
# use_jdk off -> unsets JAVA_HOME and removes bin from PATH
use_jdk() {
  local v="$1"
  if [[ "$v" == "off" || -z "$v" ]]; then
      unset JAVA_HOME
      # clear the managed path
      component_switch_path "JAVA_ACTIVE_BIN" ""
      component_set_status "JDK" "off"
      echo "JDK disabled (JAVA_HOME unset)"
      return
  fi

  local home
  home="$(_jdk_home "$v")" || { echo "JDK $v not found under $COMPONENTS/JDK"; return 1; }
  
  export JAVA_HOME="$home"
  # Swaps the path cleanly
  component_switch_path "JAVA_ACTIVE_BIN" "$JAVA_HOME/bin"
  component_set_status "JDK" "$v"
  
  echo "Switched to JDK ($v)"
  java -version
}

# Aliases (Rule of 5 and compat)
alias jdk='use_jdk'
alias jdk_use='use_jdk'
alias jdk_clear='use_jdk off'

alias jdk11='use_jdk 11'
alias jdk17='use_jdk 17'
alias jdk21='use_jdk 21'
alias jdk25='use_jdk 25'
alias jdkoff='use_jdk off'

# Enable completion
load_components_completion "use_jdk" "JDK"

