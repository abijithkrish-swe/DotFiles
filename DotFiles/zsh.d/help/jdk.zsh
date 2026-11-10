# --- jdk help module ---------------------------------------------------------
_devhelp_jdk() {
cat <<'EOF'
JDK — Quick Reference
=====================

Your portable layout
--------------------
~/Components/JDK/11/
~/Components/JDK/17/
~/Components/JDK/25/

Helper commands (from your zsh modules)
---------------------------------------
jdk_list             # approved JDK versions (from the components manifest)
use_jdk [ver]|off   # switch JAVA_HOME + PATH (no ver = manifest default; prefix ok: 26 → 26.0.2)
  e.g. use_jdk 17    # set JDK 17
       use_jdk off   # unset JAVA_HOME, fallback system Java

Shortcuts:
  jdk <ver>|off      # alias for use_jdk
  jdk11              # activate JDK 11
  jdk17              # activate JDK 17
  jdk25              # activate JDK 25

Verify active JDK
-----------------
java -version        # confirm version
javac -version       # confirm compiler
echo $JAVA_HOME      # current JAVA_HOME

Common tools
------------
jshell               # REPL (Java 9+)
jps                  # list running JVM processes
jmap <pid>           # memory map
jstack <pid>         # thread dump
jcmd <pid> GC.heap_info  # GC details

Notes
-----
• Your PATH is appended (not prepended), so system Java may still be used
  unless JAVA_HOME/bin is earlier in PATH.
• JDK switch is per-shell-session (doesn’t persist globally).
• You can default to JDK 11 by calling `jdk11` in your zshrc.
EOF
}

_devhelp_register "jdk" _devhelp_jdk
# optional alias: alias jdkhelp='devhelp jdk'