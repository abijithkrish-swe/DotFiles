# --- ant help module ----------------------------------------------------------
_devhelp_ant() {

cat <<-'EOF2'
Ant Component Management
========================

ant_list                # Approved Ant versions (from the components manifest)
use_ant [version]       # Activate (exact or prefix: 1.9 → 1.9.6; none = default)
use_ant off             # Deactivate Ant
ant_clear               # Same as 'use_ant off'
                        # aliases: ant_use, ant_off, ant_versions

Environment Variables
---------------------
ANT_HOME                # Ant home directory

Examples
--------
use_jdk 11 && use_ant   # Ant needs a JDK: activate one first
ant -f build.xml compile

Per project
-----------
.toolsrc:  ANT=1.9.6    then: toolup

Status
------
components_status       # See the active Ant version
EOF2
}

_devhelp_register "ant" _devhelp_ant
