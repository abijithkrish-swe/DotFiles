# --- gradle help module -------------------------------------------------------
_devhelp_gradle() {

cat <<-'EOF2'
Gradle Component Management
===========================

gradle_list             # Approved Gradle versions (from the components manifest)
use_gradle [version]    # Activate (exact or prefix: 9 → 9.3.1; none = default)
use_gradle off          # Deactivate Gradle
gradle_clear            # Same as 'use_gradle off'

Environment Variables
---------------------
GRADLE_HOME             # Gradle home directory

Examples
--------
use_gradle 8.14         # Switch to Gradle 8.14.4
gradle build            # Run Gradle commands (after activation)

Status
------
components_status       # See active Gradle version

Configuration
-------------
Gradle properties: $GRADLE_USER_HOME/gradle.properties (~/.local/share/gradle)
Prefer the approved `gradle` over ./gradlew — the wrapper downloads its own
distribution (see 'devhelp components').

Toolchains: Gradle may only use approved JDKs. jdk_gradle_sync (run at login)
keeps a managed block in gradle.properties: auto-download and auto-detect off,
paths = approved JDK homes. A build asking for an unapproved Java version fails
with "Cannot find a Java installation"; add that JDK to the manifest instead.

EOF2
}

_devhelp_register "gradle" _devhelp_gradle
