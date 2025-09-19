#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   export DOCKERHUB_USERNAME=youruser
#   export DOCKERHUB_TOKEN=yourtoken
#   ./scripts/deploy.sh

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH. Install kubectl on the desktop first."
  exit 1
fi

DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN:-}

if [[ -z "$DOCKERHUB_USERNAME" || -z "$DOCKERHUB_TOKEN" ]]; then
  echo "ERROR: set DOCKERHUB_USERNAME and DOCKERHUB_TOKEN environment variables before running."
  echo "Example: DOCKERHUB_USERNAME=milan DOCKERHUB_TOKEN=abc123 ./scripts/deploy.sh"
  exit 1
fi

echo "1) Create namespaces and apply monitoring stack..."
kubectl apply -f k8s/prometheus-deployment.yaml
kubectl apply -f k8s/grafana-deployment.yaml

echo "2) Create application namespace"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: canary-demo
EOF

echo "3) Create image pull secret in canary-demo (regcred)"
kubectl create secret docker-registry regcred \
  --docker-username="$DOCKERHUB_USERNAME" \
  --docker-password="$DOCKERHUB_TOKEN" \
  --docker-server=https://index.docker.io/v1/ -n canary-demo || true

echo "4) Apply analysis template and rollout (ensure you updated image in rollouts)"
kubectl apply -f k8s/analysis-template.yaml
kubectl apply -f k8s/rollout-canary.yaml

echo "5) If you have an ArgoCD instance and updated repo URL in k8s/argo-application.yaml, apply it (optional)"
if kubectl get ns argocd >/dev/null 2>&1; then
  kubectl apply -f k8s/argo-application.yaml || true
fi

echo "Done. Check resources:"
kubectl -n monitoring get pods,svc
kubectl -n canary-demo get all
echo
echo "Access Grafana: http://<DESKTOP_IP>:30001"
echo "Access app NodePort (if service exists): http://<DESKTOP_IP>:31000"

