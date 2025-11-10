_devhelp_docker() {
  cat <<'EOF'
Docker Basics
=============
Start:
  costart               # Start Colima
  docker context use colima

Run:
  docker run -it alpine sh
  docker ps / docker stop <id>

Build:
  docker build -t myimg .
  docker images

Compose:
  docker compose up -d
  docker compose down

Inspect:
  docker logs <id>
  docker exec -it <id> sh

Cleanup:
  docker system prune -af
EOF
}
_devhelp_register "docker" _devhelp_docker