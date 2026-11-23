# --- maven help module -------------------------------------------------------
_devhelp_maven() {

cat <<-'EOF2'
Maven Component Management
==========================

maven_list              # Approved Maven versions (from the components manifest)
use_maven [version]     # Activate (exact or prefix: 3.9 → 3.9.12; none = default)
use_maven off           # Deactivate Maven
                        # aliases: maven_use, maven_off, maven_versions
maven_clear             # Same as 'use_maven off'

Environment Variables
---------------------
M2_HOME                 # Maven home directory
MAVEN_HOME              # Maven home directory (alternative)

Examples
--------
use_maven 3.9           # Switch to Maven 3.9.12
mvn clean install       # Run Maven commands (after activation)
use_maven off           # Remove from PATH
maven_list              # Show approved versions

Status
------
components_status       # See active Maven version

Configuration
-------------
Maven settings: ~/.m2/settings.xml
Local repository: ~/.m2/repository (default)

EOF2
}

_devhelp_register "maven" _devhelp_maven
