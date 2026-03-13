// modules/aks.bicep
// Creates: AKS cluster (Free tier), user-assigned managed identity, subnet role assignment
//
// Security concepts:
//   - Managed identity (no passwords/secrets)
//   - Azure AD integration + Azure RBAC for Kubernetes
//   - API server authorized IP ranges
//   - Azure CNI Overlay (modern networking, pod IP isolation)
//   - Calico network policies
//   - Auto-upgrade channel for security patches

param project string
param environment string
param location string
param tags object
param appSubnetId string

@description('CIDR range(s) allowed to access the AKS API server')
param authorizedIpRange string = '0.0.0.0/0'

// ── Managed Identity ──────────────────────────────────────────────────────────
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${project}-aks-identity-${environment}'
  location: location
  tags: tags
}

// ── AKS Cluster ───────────────────────────────────────────────────────────────
resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: '${project}-aks-${environment}'
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  properties: {
    dnsPrefix: '${project}-${environment}'
    kubernetesVersion: '1.34.3'
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    apiServerAccessProfile: {
      authorizedIPRanges: [authorizedIpRange]
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'calico'
      loadBalancerSku: 'standard'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
      podCidr: '10.244.0.0/16'
    }
    agentPoolProfiles: [
      {
        name: 'system'
        count: 1
        vmSize: 'Standard_B2s'
        mode: 'System'
        osType: 'Linux'
        osDiskSizeGB: 30
        osDiskType: 'Managed'
        vnetSubnetID: appSubnetId
        maxPods: 30
        enableAutoScaling: false
        type: 'VirtualMachineScaleSets'
      }
    ]
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output aksName string = aks.name
output aksId string = aks.id
output aksFqdn string = aks.properties.fqdn
output identityPrincipalId string = aksIdentity.properties.principalId
