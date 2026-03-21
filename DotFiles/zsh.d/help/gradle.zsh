# --- gradle help module -------------------------------------------------------
_devhelp_gradle() {

cat <<-'EOF'
Gradle Component Management
===========================

gradle_list             # List available Gradle versions
use_gradle <version>    # Activate a specific Gradle version
use_gradle off          # Deactivate Gradle
gradle_clear            # Same as 'use_gradle off'

Environment Variables
---------------------
GRADLE_HOME             # Gradle home directory

Examples
--------
use_gradle 8.0          # Switch to Gradle 8.0
gradle build            # Run Gradle commands (after activation)

Status
------
components_status       # See active Gradle version

Configuration
-------------
Gradle properties: ~/.gradle/gradle.properties

EOF
}

_devhelp_register "gradle" _devhelp_gradle
