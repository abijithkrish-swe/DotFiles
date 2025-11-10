# --- devhelp: colima ---------------------------------------------------------
_devhelp_colima() {
  cat <<'EOF'
Colima — Docker & Kubernetes (no Docker Desktop)
================================================
Start / Stop:
  costart                   # start Colima (Docker + Kubernetes)
  corest                    # restart
  costop                    # stop
  codrop                    # delete VM (DANGER: wipes images/volumes within)

Context:
  couse                     # set Docker CLI context to 'colima'
  coinfo                    # show Colima status + docker/kube contexts

Docker (after costart + couse):
  docker ps                 # list containers
  docker run -it alpine sh  # quick shell
  docker build -t myimg .   # build image
  docker compose up         # compose works if docker-compose installed

Kubernetes (when started with --kubernetes):
  kubectl get nodes
  kubectl get pods -A
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm install nginx bitnami/nginx

Hints:
  • Config file: ~/.colima/default.yaml (CPU/RAM/Disk, runtime, k8s=true)
  • Switch runtime: containerd → use nerdctl (docker-compatible)
  • Images live inside the Colima VM; export with 'docker save' if needed
EOF
}
_devhelp_register "colima" _devhelp_colima