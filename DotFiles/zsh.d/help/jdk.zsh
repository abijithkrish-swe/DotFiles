# --- jdk help module ---------------------------------------------------------
_devhelp_jdk() {
cat <<'EOF'
JDK — Quick Reference
=====================

Your portable layout
--------------------
~/Components/JDK/<ver>/     # flat (11) or macOS bundle (Contents/Home)
  approved: see jdk_list (11, 17, 25, 26.0.2)

Helper commands (from your zsh modules)
---------------------------------------
jdk_list             # approved JDK versions (from the components manifest)
use_jdk [ver]|off   # switch JAVA_HOME + PATH (no ver = manifest default; prefix ok: 26 → 26.0.2)
                     # aliases: jdk_use, jdk_versions (= jdk_list), jdk_clear / jdkoff
  e.g. use_jdk 17    # set JDK 17
       use_jdk off   # unset JAVA_HOME, fallback system Java

jdk_gradle_sync      # limit Gradle toolchains to approved JDKs (runs at login)

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
• JAVA_HOME/bin is prepended to PATH, so it wins over system Java.
• JDK switch is per-shell-session (doesn’t persist globally).
• JDK 11 is autoloaded at login (manifest `autoload`); change it in the
  components manifest, not in zshrc — see 'devhelp components'.
EOF
}

_devhelp_register "jdk" _devhelp_jdk
# optional alias: alias jdkhelp='devhelp jdk'