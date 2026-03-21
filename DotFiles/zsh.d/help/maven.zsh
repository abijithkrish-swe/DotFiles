# --- maven help module -------------------------------------------------------
_devhelp_maven() {

cat <<-'EOF'
Maven Component Management
==========================

maven_list              # List available Maven versions
use_maven <version>     # Activate a specific Maven version
use_maven off           # Deactivate Maven
maven_clear             # Same as 'use_maven off'

Environment Variables
---------------------
M2_HOME                 # Maven home directory
MAVEN_HOME              # Maven home directory (alternative)

Examples
--------
use_maven 3.9.6         # Switch to Maven 3.9.6
mvn clean install       # Run Maven commands (after activation)
use_maven off           # Remove from PATH
maven_list              # Show all installed versions

Status
------
components_status       # See active Maven version

Configuration
-------------
Maven settings: ~/.m2/settings.xml
Local repository: ~/.m2/repository (default)

EOF
}

_devhelp_register "maven" _devhelp_maven
