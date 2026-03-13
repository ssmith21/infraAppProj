// subscription.bicep
// Scope: subscription — creates the resource group
// Deploy with: az deployment sub create --location canadacentral --template-file bicep/subscription.bicep --parameters bicep/parameters/dev.bicepparam

targetScope = 'subscription'

@description('Project short name used in resource naming')
param project string

@description('Environment name')
@allowed(['dev'])
param environment string

@description('Azure region for all resources')
param location string = 'canadacentral'

@description('Tags applied to all resources')
param tags object = {
  project: project
  environment: environment
  managedBy: 'bicep'
}

// Resource Group — everything else deploys into this
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${project}-rg-${environment}'
  location: location
  tags: tags
}

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
