# --- devhelp: kubernetes (k8s) ----------------------------------------------
_devhelp_k8s() {
  cat <<'EOF'
Kubernetes Basics (Colima local cluster)
=======================================

Start Colima with K8s:
  costart                      # starts Colima VM + K8s
  kubectl get nodes            # confirm cluster is ready
  kubectl cluster-info         # show master & DNS

Pods:
  kubectl run test --image=alpine -- sleep 3600
  kubectl get pods
  kubectl exec -it test -- sh
  kubectl delete pod test

Deployments:
  kubectl create deployment web --image=nginx:alpine
  kubectl get deployments
  kubectl describe deployment web
  kubectl delete deployment web

Services:
  kubectl expose deployment web --port=80 --type=NodePort
  kubectl get svc web -o wide
  kubectl delete svc web

Apply YAML:
  kubectl apply -f app.yaml
  kubectl delete -f app.yaml

Namespace management:
  kubectl get ns
  kubectl create ns dev
  kubectl config set-context --current --namespace=dev

Logs & Troubleshooting:
  kubectl logs <pod>
  kubectl describe pod <pod>
  kubectl get events --sort-by=.metadata.creationTimestamp

Cleanup:
  kubectl delete all --all
  kubectl config get-contexts
  kubectl config use-context colima

EOF
}
_devhelp_register "k8s" _devhelp_k8s