// main.bicep
// Scope: resource group — orchestrates all modules
// Deploy with: az deployment group create --resource-group <rg> --template-file bicep/main.bicep --parameters bicep/parameters/dev.bicepparam

targetScope = 'resourceGroup'

@description('Project short name used in resource naming')
param project string

@description('Environment name')
@allowed(['dev'])
param environment string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Tags applied to all resources')
param tags object = {
  project: project
  environment: environment
  managedBy: 'bicep'
}

@description('CIDR range allowed to access the AKS API server (e.g. your public IP/32)')
param authorizedIpRange string = '0.0.0.0/0'


// ── Networking ──────────────────────────────────────────────────────────────
module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    project: project
    environment: environment
    location: location
    tags: tags
  }
}

// ── AKS Cluster ─────────────────────────────────────────────────────────────
module aks 'modules/aks.bicep' = {
  name: 'aks'
  params: {
    project: project
    environment: environment
    location: location
    tags: tags
    appSubnetId: networking.outputs.appSubnetId
    authorizedIpRange: authorizedIpRange
  }
}

// ── Role Assignment: Network Contributor on VNet for AKS identity ───────────
// Scoped to the VNet so AKS can manage load balancer rules and route tables
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: '${project}-vnet-${environment}'
}

resource aksNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, '${project}-aks-identity-${environment}', 'network-contributor')
  scope: vnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: aks.outputs.identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}


// ── Outputs ─────────────────────────────────────────────────────────────────
output vnetId string = networking.outputs.vnetId
output vnetName string = networking.outputs.vnetName
output appSubnetId string = networking.outputs.appSubnetId
output dataSubnetId string = networking.outputs.dataSubnetId
output aksName string = aks.outputs.aksName
output aksFqdn string = aks.outputs.aksFqdn
