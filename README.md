# InfraApp — Azure AKS Sandbox

Azure-based sandbox infrastructure running a minimal web app on AKS, managed entirely with Bicep IaC.

## Architecture

![Architecture Diagram](docs/architecture.png)

*(Regenerate with: `npx @mermaid-js/mermaid-cli mmdc -i docs/architecture.md -o docs/architecture.png -t neutral -b white`, or paste [docs/architecture.md](docs/architecture.md) into [mermaid.live](https://mermaid.live))*

### Components

| Component | Purpose | Cost |
|-----------|---------|------|
| VNet (10.0.0.0/16) | Network isolation with 4 segmented subnets | Free |
| AKS (Free tier) | Kubernetes cluster, 1x Standard_B2s node | ~$12 CAD/mo |
| Standard Load Balancer | Routes HTTP traffic to the cluster | ~$25 CAD/mo |
| Public IP | Entry point for web traffic | ~$5 CAD/mo |
| **Total** | | **~$42 CAD/mo** |

## Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) with Bicep
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- An Azure subscription (Visual Studio Enterprise / MSDN)

### 1. Deploy Infrastructure

Infrastructure deploys automatically via GitHub Actions when you push changes to `bicep/**`. For the first deployment or to deploy manually:

```bash
az login
./scripts/deploy.sh bootstrap   # Create resource group (one-time)
./scripts/deploy.sh deploy      # Deploy all infrastructure
```

### 2. Deploy the App

App deploys automatically via GitHub Actions when you push changes to `k8s/**`. To deploy manually:

```bash
./scripts/deploy-app.sh
```

### 3. Access the Welcome Page

```bash
kubectl get service welcome -n welcome-app
# Open http://<EXTERNAL-IP> in your browser
```

### Manual Cluster Start/Stop

The cluster does not run automatically. Start it when you want to use it and stop it to pause compute charges.

```bash
./scripts/deploy.sh start   # Start cluster + configure kubectl
./scripts/deploy.sh stop    # Stop cluster (pauses VM compute charges)
```

## GitHub Actions CI/CD

Two workflows automatically deploy changes on push to `main`.

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `deploy-infra.yml` | Push touching `bicep/**`, or manual | Validates Bicep, bootstraps resource group, deploys infrastructure |
| `deploy-app.yml` | Push touching `k8s/**`, or manual | Gets AKS credentials, applies all Kubernetes manifests |

### Authentication: OIDC (no stored secrets)

Workflows authenticate to Azure using OpenID Connect (OIDC) federated credentials. GitHub generates a short-lived token per run; Azure validates it without any stored client secret. This is more secure than storing a client secret because:
- No long-lived credential to leak or rotate
- Token is scoped to a specific repository and branch
- Each token expires after the workflow run

### One-Time Setup

**Step 1 — Create a Service Principal and grant Owner at subscription scope:**
```bash
az ad app create --display-name "infraapp-github-actions"
# Note the appId from output

az ad sp create --id <appId>

az role assignment create --assignee <appId> --role Owner \
  --scope /subscriptions/<subscriptionId>
```

> Owner is required because the Bicep template creates role assignments, which require Owner or User Access Administrator.

**Step 2 — Add federated credential for the main branch:**
```bash
az ad app federated-credential create --id <appId> --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<owner>/<repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

**Step 3 — Add GitHub secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | `appId` from Step 1 |
| `AZURE_TENANT_ID` | Your Azure tenant ID (`az account show --query tenantId -o tsv`) |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID (`az account show --query id -o tsv`) |

**Step 4 — Delete the existing Automation Account** (it was removed from Bicep but remains in Azure):
```bash
az automation account delete --resource-group infraapp-rg-dev --name infraapp-automation-dev --yes
```

## Security Concepts

This project implements **23 security concepts**, all at zero additional cost:

### Network Security (Infrastructure Layer)

- **VNet Isolation** — All resources live in a dedicated virtual network, isolated from other Azure tenants and subscriptions. Traffic between the VNet and the internet is controlled at every boundary.
- **Subnet Segmentation** — Four subnets (public, app, data, mgmt) separate resources by function. Lateral movement between tiers is blocked by default.
- **NSG Rules** — Each subnet has a Network Security Group with least-privilege inbound rules. Only explicitly allowed traffic passes; everything else is denied.
- **Defense in Depth** — Multiple overlapping security layers (NSG + Kubernetes Network Policy + Pod Security) so that a failure in one layer doesn't expose the system.

### Identity & Access (Control Plane)

- **Managed Identity** — The AKS cluster authenticates using an Azure-managed identity. No passwords, keys, or secrets are stored anywhere.
- **Azure AD Integration** — Cluster authentication is backed by Azure Active Directory. Users authenticate with their Azure AD credentials, not Kubernetes-specific tokens.
- **Azure RBAC for Kubernetes** — Azure role-based access control gates who can access the cluster and what actions they can perform.
- **Kubernetes RBAC** — Fine-grained permissions within the cluster control what pods and services can do.
- **API Server IP Allowlisting** — The `authorizedIPRanges` parameter restricts which IPs can reach the Kubernetes API server (currently open; tighten to your IP for added security).
- **OIDC Authentication (CI/CD)** — GitHub Actions authenticates to Azure without stored secrets using short-lived federated tokens.

### Workload Security (Pod Layer)

- **Pod Security Standards** — The namespace enforces the `baseline` standard and audits/warns on `restricted`. This prevents privilege escalation, host namespace access, and other dangerous pod configurations.
- **Non-root Container** — The nginx container runs as UID 101 (the nginx user), not root. Even if compromised, the attacker can't modify system files.
- **Read-only Root Filesystem** — The container's filesystem is mounted read-only. Attackers can't write malware or modify application files.
- **Drop All Capabilities** — Linux capabilities (like `NET_RAW`, `SYS_ADMIN`) are explicitly dropped. The container can't perform any privileged kernel operations.
- **No Privilege Escalation** — `allowPrivilegeEscalation: false` prevents processes from gaining more privileges than their parent.
- **Seccomp Profile** — The `RuntimeDefault` seccomp profile restricts which system calls the container can make, reducing the kernel attack surface.
- **No Service Account Token** — `automountServiceAccountToken: false` prevents the Kubernetes API token from being mounted into the pod, blocking lateral movement within the cluster.
- **Resource Limits** — CPU and memory limits prevent a compromised container from consuming all node resources (denial-of-service).
- **Pinned Image Version** — Using `nginx:1.27-alpine` instead of `latest` ensures reproducible builds and prevents supply chain attacks from tag mutation.

### Network Security (Kubernetes Layer)

- **Network Policies (Calico)** — A default-deny policy blocks all ingress traffic to pods. An explicit allow rule permits only port 8080 to the welcome app. East-west traffic between pods is blocked.
- **Service-level Exposure** — Only port 80 is exposed via the LoadBalancer. No other ports are reachable from the internet.

### Operational Security

- **Auto-upgrade Channel** — The cluster automatically upgrades to the latest stable Kubernetes version, ensuring security patches are applied without manual intervention.
- **Infrastructure as Code** — All infrastructure is defined in Bicep, making changes auditable, reviewable, and version-controlled. No manual portal changes.

## Project Structure

```
infraAppProj/
├── README.md                          # This file
├── CLAUDE.md                          # AI assistant instructions
├── .github/
│   └── workflows/
│       ├── deploy-infra.yml           # CI/CD: deploy Bicep on push
│       └── deploy-app.yml             # CI/CD: deploy K8s manifests on push
├── bicep/
│   ├── main.bicep                     # Orchestrates all modules
│   ├── subscription.bicep             # Creates resource group
│   ├── modules/
│   │   ├── networking.bicep           # VNet, subnets, NSGs
│   │   └── aks.bicep                  # AKS cluster
│   └── parameters/
│       └── dev.bicepparam             # Environment parameters
├── k8s/
│   ├── namespace.yaml                 # Namespace with PSS labels
│   ├── configmap.yaml                 # HTML page + nginx config
│   ├── deployment.yaml                # Hardened nginx deployment
│   ├── service.yaml                   # LoadBalancer service
│   └── networkpolicy.yaml             # Default-deny + allow rules
├── scripts/
│   ├── deploy.sh                      # Infrastructure deployment wrapper
│   └── deploy-app.sh                  # Kubernetes manifest deployment
└── docs/
    ├── architecture.md                # Mermaid diagram source
    └── architecture.png               # Rendered diagram
```

## Deployment Commands

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh bootstrap` | Create resource group (one-time) |
| `./scripts/deploy.sh whatif` | Preview infrastructure changes |
| `./scripts/deploy.sh deploy` | Deploy all infrastructure manually |
| `./scripts/deploy.sh validate` | Check Bicep syntax |
| `./scripts/deploy.sh start` | Start AKS cluster |
| `./scripts/deploy.sh stop` | Stop AKS cluster |
| `./scripts/deploy-app.sh` | Deploy K8s manifests manually |
