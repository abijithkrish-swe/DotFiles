# --- devhelp: colima ---------------------------------------------------------
_devhelp_colima() {
  cat <<'EOF'
Colima — Docker & Kubernetes (no Docker Desktop)
================================================
Start / Stop:
  costart                   # start Colima (Docker + Kubernetes)
  costart_lite              # start without Kubernetes (less RAM and idle CPU)
  corest                    # restart
  costop                    # stop
  colist                    # list Colima VMs (CPUs, RAM, disk)
  codrop                    # delete VM (DANGER: wipes images/volumes within)

Context:
  couse                     # set Docker CLI context to 'colima'
  coinfo                    # show Colima status + docker/kube contexts

Usage & cleanup:
  docker_usage              # VM RAM on the Mac, memory per container, disk, images by repo,
                            # unused volumes, stopped containers (read-only)
  docker_clean cache        # build cache
  docker_clean dangling     # untagged images
  docker_clean images lorebase 3 -n   # dry run: all lorebase tags except the newest 3
  docker_clean containers   # stopped containers
  docker_clean volumes      # unused volumes, one by one (app data! never signoz-*)
                            # every step asks first; pinned and in-use images are kept
  colima ssh -- sudo fstrim -av   # afterwards: give the freed space back to macOS
                            # (the VM disk file never shrinks by itself; 67 GB -> 13 GB once)

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
  • Running VM's settings: ~/.config/colima/default/colima.yaml ($COLIMA_HOME).
    Resize: colima stop && colima start --cpu 4 --memory 8 --kubernetes
  • New VMs start from ~/.config/colima/_templates/default.yaml (dotfiles:
    DotFiles/config/colima/_templates/default.yaml): 4 CPU, 8 GB, 100 GB, k3s.
  • Switch runtime: containerd → use nerdctl (docker-compatible)
  • Images live inside the Colima VM; export with 'docker save' if needed
EOF
}
_devhelp_register "colima" _devhelp_colima