// modules/networking.bicep
// Creates: VNet, four subnets, NSGs per subnet
//
// Subnet layout (10.0.0.0/16):
//   public-subnet  10.0.0.0/24  — internet-facing ingress (load balancers, App Gateway)
//   app-subnet     10.0.1.0/24  — AKS nodes (no direct internet except HTTP via LB)
//   data-subnet    10.0.2.0/24  — databases, private endpoints (app-subnet access only)
//   mgmt-subnet    10.0.3.0/24  — bastion, management tooling

param project string
param environment string
param location string
param tags object

// ── NSGs ────────────────────────────────────────────────────────────────────

// public-subnet NSG: allow HTTP/HTTPS inbound from internet
resource nsgPublic 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${project}-nsg-public-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// app-subnet NSG: allow inbound from public-subnet only, deny direct internet
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${project}-nsg-app-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowFromPublicSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '10.0.0.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// data-subnet NSG: allow inbound from app-subnet only
resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${project}-nsg-data-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowFromAppSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '10.0.1.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// mgmt-subnet NSG: allow SSH/RDP from VNet only (tighten with your own IP in prod)
resource nsgMgmt 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${project}-nsg-mgmt-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSshFromVnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// ── VNet + Subnets ───────────────────────────────────────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${project}-vnet-${environment}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'public-subnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsgPublic.id }
        }
      }
      {
        name: 'app-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsgApp.id }
          // AKS nodes deploy into this subnet — no delegation required
        }
      }
      {
        name: 'data-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: { id: nsgData.id }
          privateEndpointNetworkPolicies: 'Disabled' // required for private endpoints
        }
      }
      {
        name: 'mgmt-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: { id: nsgMgmt.id }
        }
      }
    ]
  }
}

// ── Outputs ──────────────────────────────────────────────────────────────────

output vnetId string = vnet.id
output vnetName string = vnet.name
output publicSubnetId string = vnet.properties.subnets[0].id
output appSubnetId string = vnet.properties.subnets[1].id
output dataSubnetId string = vnet.properties.subnets[2].id
output mgmtSubnetId string = vnet.properties.subnets[3].id
