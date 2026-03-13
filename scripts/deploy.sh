#!/usr/bin/env bash
# deploy.sh — wrapper for common Bicep deployment operations
# Usage: ./scripts/deploy.sh <command> [environment]
#   commands: bootstrap, whatif, deploy
#   environment: dev (default)

set -euo pipefail

COMMAND="${1:-help}"
ENV="${2:-dev}"
PROJECT="infraapp"
LOCATION="canadacentral"
RG_NAME="${PROJECT}-rg-${ENV}"
PARAM_FILE="bicep/parameters/${ENV}.bicepparam"

case "$COMMAND" in

  # Step 1: Create the resource group (subscription-scoped deployment)
  bootstrap)
    echo "Creating resource group for environment: ${ENV}"
    az deployment sub create \
      --location "$LOCATION" \
      --template-file bicep/subscription.bicep \
      --parameters project="$PROJECT" environment="$ENV" location="$LOCATION" \
      --name "bootstrap-${ENV}-$(date +%Y%m%d%H%M%S)"
    echo "Resource group '${RG_NAME}' ready."
    ;;

  # Step 2: Preview changes without applying
  whatif)
    echo "Running what-if for environment: ${ENV}"
    az deployment group what-if \
      --resource-group "$RG_NAME" \
      --template-file bicep/main.bicep \
      --parameters "$PARAM_FILE"
    ;;

  # Step 3: Deploy all resources
  deploy)
    echo "Deploying to environment: ${ENV}"
    az deployment group create \
      --resource-group "$RG_NAME" \
      --template-file bicep/main.bicep \
      --parameters "$PARAM_FILE" \
      --name "deploy-${ENV}-$(date +%Y%m%d%H%M%S)"
    ;;

  # Validate Bicep syntax without deploying
  validate)
    echo "Validating Bicep files..."
    az bicep build --file bicep/main.bicep
    az bicep build --file bicep/subscription.bicep
    echo "Validation passed."
    ;;

  # Start the AKS cluster (manual override)
  start)
    echo "Starting AKS cluster..."
    az aks start --resource-group "$RG_NAME" --name "${PROJECT}-aks-${ENV}"
    az aks get-credentials --resource-group "$RG_NAME" --name "${PROJECT}-aks-${ENV}" --overwrite-existing
    echo "Cluster started and credentials configured."
    ;;

  # Stop the AKS cluster (manual override)
  stop)
    echo "Stopping AKS cluster..."
    az aks stop --resource-group "$RG_NAME" --name "${PROJECT}-aks-${ENV}"
    echo "Cluster stopped."
    ;;

  *)
    echo "Usage: $0 <bootstrap|whatif|deploy|validate|start|stop> [dev]"
    echo ""
    echo "  bootstrap  — create resource group (run once)"
    echo "  whatif     — preview changes (dry run)"
    echo "  deploy     — apply all infrastructure changes"
    echo "  validate   — check Bicep syntax"
    echo "  start      — start AKS cluster (manual override)"
    echo "  stop       — stop AKS cluster (manual override)"
    exit 1
    ;;
esac
