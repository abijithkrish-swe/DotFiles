# --- mysql help module -------------------------------------------------------
_devhelp_mysql() {
cat <<'EOF'
MySQL — Quick Reference
=======================

Your portable layout (per version)
----------------------------------
~/Components/Mysql/<VER>/
  ├─ Core/      # binaries
  ├─ Data/      # datadir (InnoDB, binlogs)
  ├─ Conf/      # my.cnf lives here
  └─ Log/       # slow.log, error.log, general.log (binlogs stay in Data)

Helper commands (from your zsh modules)
---------------------------------------
mysqlv                       # list installed versions
mysql_conf_inspect <ver>     # print key values from Conf/my.cnf
mysql_init <ver>             # initialize Data/ (refuses if not empty)
mysql_start <ver>            # start mysqld with Conf/my.cnf
mysql_ready <ver> [timeout]  # wait until server responds
mysql_cli [ver] [args...]    # mysql client for default or specific version
mysql_stop <ver>             # stop the server (mysqladmin/pidfile)
mysql_set_default <ver>      # append Core/bin to PATH for client

Common client usage
-------------------
mysql -u root -p
mysql -h 127.0.0.1 -P 3306 -u root -p
mysql --local-infile=1 -u root -p

Useful SQL snippets
-------------------
SHOW DATABASES;
CREATE DATABASE appdb;
CREATE USER 'app'@'%' IDENTIFIED BY 'secret';
GRANT ALL ON appdb.* TO 'app'@'%';
FLUSH PRIVILEGES;

SHOW VARIABLES LIKE 'log_error';
SHOW VARIABLES LIKE 'slow_query_log%';
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW ENGINE INNODB STATUS\G

Maintenance
-----------
mysqldump -u root -p --single-transaction appdb > dump.sql
mysqladmin -u root -p shutdown

Troubleshooting
---------------
• Can't connect: check socket vs TCP; use -h 127.0.0.1 to force TCP.
• Init fails: ensure Data/ empty; remove lost+found on macOS if present.
• Port busy: lsof -i :3306 | awk 'NR>1{print $2}' | xargs kill -9
EOF
}

_devhelp_register "mysql" _devhelp_mysql
# (optional) alias in your zshrc: alias mysqlhelp='devhelp mysql'