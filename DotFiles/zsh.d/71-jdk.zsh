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

# jdk <ver|off>
#   jdk 11 | 17 | 25  -> sets JAVA_HOME and appends bin to PATH
#   jdk off           -> unsets JAVA_HOME (PATH left untouched)
jdk() {
  local v="$1"
  case "$v" in
    off|"")
      unset JAVA_HOME
      hash -r
      java -version 2>/dev/null || echo "JDK off"
      ;;
    *)
      local home
      home="$(_jdk_home "$v")" || { echo "JDK $v not found under $COMPONENTS/JDK"; return 1; }
      export JAVA_HOME="$home"
      # append (safer: system/brew JDKs win if present)
      export PATH="$PATH:$JAVA_HOME/bin"
      hash -r
      java -version
      ;;
  esac
}

# Shortcuts
alias jdk11='jdk 11'
alias jdk17='jdk 17'
alias jdk25='jdk 25'
alias jdkoff='jdk off'

# ---------------------------------------------------------------------
# 72) Redis helpers
# ---------------------------------------------------------------------