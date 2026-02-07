# --- mysql help module -------------------------------------------------------
_devhelp_mysql() {
cat <<'EOF'
MySQL — Quick Reference
=======================

Portable layout (per version)
-----------------------------
~/Components/Mysql/<VER>/
  ├─ Core/      # binaries (mysql, mysqld)
  ├─ Data/      # datadir (InnoDB, binlogs, ib*)
  ├─ Conf/      # my.cnf (optional)
  ├─ Log/       # error.log, slow.log, query.log
  └─ Run/       # mysqld.sock, mysqld.pid, run.env (auto-generated)

Core helper commands
--------------------
mysql_list                     # list available valid versions
use_mysql <ver>|off            # switch PATH & envs to version (adds Core/bin)
mysql_start [--port N] [ver]   # start server; asks to stop or auto-picks free port
mysql_stop [ver]               # cleanly stop server (mysqladmin or pid)
mysql_cli [args...]            # mysql client for current version; auto uses socket
mysql_current                  # show active version, status, port, pid, paths
mysql_clear                    # remove MySQL from PATH

Aliases:
  mysql_versions -> mysql_list

Quick examples
--------------
# switch to version and start it
use_mysql 8.0.43
mysql_start

# connect (socket auto-detected)
mysql_cli -uroot -p

# start another version in parallel on new port
mysql_start --port 3310 5.7.44

# stop currently running instance
mysql_stop

# view info on active setup
mysql_current

Config & data locations
-----------------------
Default components root:   $HOME/Components/Mysql
Default version:           (from $DEFAULT_MYSQL)
Each version defines:
  Data/:      actual MySQL datadir
  Log/:       error / slow / query logs
  Run/:       socket, pid, run.env (port, pid info)
  Conf/my.cnf optional configuration file

Maintenance & CLI basics
------------------------
mysql -u root -p
mysql -h 127.0.0.1 -P 3306 -u root -p
mysqldump -u root -p --single-transaction appdb > dump.sql
mysqladmin -u root -p shutdown

Common SQL
----------
SHOW DATABASES;
CREATE DATABASE appdb;
CREATE USER 'app'@'%' IDENTIFIED BY 'secret';
GRANT ALL ON appdb.* TO 'app'@'%';
FLUSH PRIVILEGES;
SHOW VARIABLES LIKE 'log_error';
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW ENGINE INNODB STATUS\G

Troubleshooting
---------------
• Can't connect: check socket vs TCP; use -h 127.0.0.1 to force TCP.
• Data init fails: ensure Data/ empty; remove lost+found if present (macOS).
• Port busy: mysql_start auto-picks a free port (starting 3307) or ask to stop existing.
• To reset: delete Run/run.env and start again.

EOF
}

_devhelp_register "mysql" _devhelp_mysql
# optional zshrc alias:
# alias mysqlhelp='devhelp mysql'