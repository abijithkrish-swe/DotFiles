# TEST

Verification checklist after installing dotfiles.

---

## ✅ Environment Variables

- `echo $HISTFILE` → should be `~/.zshcache/zsh_history`
- `echo $MYSQL_HISTFILE` → should be `~/.zshcache/mysql_history`
- `echo $_ZO_DATA_DIR` → should be `~/.zshcache/zoxide`
- `echo $PATH` → should include Components/bin if toggled

---

## ☕ JDK

```sh
java -version
```
→ default should be JDK 11

Switch test:
```sh
jdk17 && java -version
```

---

## 🐬 MySQL

```sh
mysql --version
```
→ client should be 8.0.43 by default

Test server:
```sh
mysql_start 8.0.43
mysql -u root -e "SELECT VERSION();"
mysql_stop
```

---

## 🔴 Redis

```sh
redis-cli --version
```
→ default should be 7.0

Switch test:
```sh
use_redis 6.4 && redis-cli --version
```

---

## ⚙️ Tools

Check versions:
```sh
fzf --version
rg --version
bat --version
fd --version
eza --version
zoxide --version
tmux -V
starship --version
```

---

## 🧩 Secrets

```sh
load_secrets
show_secret SOME_KEY
```

---

## 🌱 Git Config

```sh
git config --list --show-origin
```
→ should load from `~/.config/git/config`

---

## ✍️ Vim

Open a file, make changes, and check:

```sh
ls ~/.zshcache/vim/
```
→ should see swap, backup, undo files

---

## 🧩 Observability (Mac only)

- `btop` — system monitor (CPU/mem/net/disk UI)
- `tldr CMD` — quick manpage with examples (try `tldr tar`)
- `procs` — better `ps` (`procs -t` for tree, `procs -Q <pat>` to filter)

Help:
```sh
devhelp obs
```

---