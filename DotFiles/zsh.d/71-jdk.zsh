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
