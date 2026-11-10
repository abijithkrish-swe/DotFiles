# 71) JDK
# Versions and layout (Contents/Home or flat) come from the components manifest.

jdk_list() { components_list jdk JDK; }

# Switch JDK version
# use_jdk 17   -> sets JAVA_HOME and prepends bin to PATH
# use_jdk      -> manifest default
# use_jdk off  -> unsets JAVA_HOME and removes bin from PATH
use_jdk() {
  if [[ "$1" == "off" ]]; then
    components_deactivate jdk JDK JAVA_ACTIVE_BIN
    echo "JDK disabled (JAVA_HOME unset)"
    return
  fi
  components_activate jdk JDK JAVA_ACTIVE_BIN "$1" || return 1
  echo "Switched to JDK ($CM_V)"
  java -version
}

# jdk_gradle_sync — point Gradle toolchains at the approved JDKs only.
# Writes a marked block into $GRADLE_USER_HOME/gradle.properties (rest of the
# file untouched): auto-download and auto-detect off, installations.paths =
# every approved JDK home. Without it, a build asking for a Java version you
# don't have makes Gradle download one. Runs at login (79-defaults) when the
# block would change; run it by hand after editing the manifest.
jdk_gradle_sync() {
  emulate -L zsh
  local file="${GRADLE_USER_HOME:-$HOME/.gradle}/gradle.properties" v block current
  local -a homes
  components_ensure_loaded || return 1
  for v in ${=CM_VERSIONS[jdk]}; do
    components_resolve jdk "$v" 2>/dev/null && homes+=("$CM_HOME")
  done
  block="# >>> managed by jdk_gradle_sync (components manifest) — do not edit
org.gradle.java.installations.auto-download=false
org.gradle.java.installations.auto-detect=false
org.gradle.java.installations.paths=${(j:,:)homes}
# <<< managed by jdk_gradle_sync"
  if [[ -f "$file" ]]; then
    current="$(sed -n '/^# >>> managed by jdk_gradle_sync/,/^# <<< managed by jdk_gradle_sync/p' "$file")"
    [[ "$current" == "$block" ]] && return 0
    sed -i '' '/^# >>> managed by jdk_gradle_sync/,/^# <<< managed by jdk_gradle_sync/d' "$file"
  else
    mkdir -p "${file:h}"
  fi
  print -r -- "$block" >> "$file"
  echo "Gradle toolchains → approved JDKs only (${#homes} paths) in $file"
}

# Aliases (Rule of 5 and compat)
alias jdk='use_jdk'
alias jdk_use='use_jdk'
alias jdk_clear='use_jdk off'
alias jdk_versions='jdk_list'

alias jdk11='use_jdk 11'
alias jdk17='use_jdk 17'
alias jdk25='use_jdk 25'
alias jdkoff='use_jdk off'

# Enable completion
load_components_completion "use_jdk" "jdk"
