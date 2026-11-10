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
Gradle properties: ~/.gradle/gradle.properties
Prefer the approved `gradle` over ./gradlew — the wrapper downloads its own
distribution (see 'devhelp components').

EOF2
}

_devhelp_register "gradle" _devhelp_gradle
