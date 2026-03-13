#!/usr/bin/env bash
# Deploy Kubernetes manifests to the AKS cluster
set -euo pipefail

ENV="${1:-dev}"
RG="infraapp-rg-${ENV}"
CLUSTER="infraapp-aks-${ENV}"

echo "Getting AKS credentials..."
az aks get-credentials --resource-group "$RG" --name "$CLUSTER" --overwrite-existing

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/networkpolicy.yaml

echo ""
echo "Waiting for external IP (Ctrl+C to stop watching)..."
kubectl get service welcome -n welcome-app --watch
