// ============================================================================
// Virtual Network Module
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Creates VNet with subnets for AVD deployment
// ============================================================================

@description('VNet name')
param vnetName string

@description('Azure region')
param location string

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('AVD subnet name')
param avdSubnetName string = 'snet-avd'

@description('AVD subnet address prefix')
param avdSubnetPrefix string = '10.0.1.0/24'

@description('Enable Azure Bastion subnet')
param enableBastionSubnet bool = true

@description('Bastion subnet address prefix')
param bastionSubnetPrefix string = '10.0.255.0/26'

@description('Tags')
param tags object = {}

// ============================================================================
// Resources
// ============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: concat([
      {
        name: avdSubnetName
        properties: {
          addressPrefix: avdSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
    ], enableBastionSubnet ? [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ] : [])
  }
}

// NSG for AVD subnet
resource avdNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${avdSubnetName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRDP-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'AllowHTTPS-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowAzureFiles-Outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Storage'
          destinationPortRange: '445'
        }
      }
    ]
  }
}

// Associate NSG with AVD subnet
resource nsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  parent: vnet
  name: avdSubnetName
  properties: {
    addressPrefix: avdSubnetPrefix
    networkSecurityGroup: {
      id: avdNsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('VNet resource ID')
output vnetId string = vnet.id

@description('VNet name')
output vnetName string = vnet.name

@description('AVD subnet resource ID')
output avdSubnetId string = '${vnet.id}/subnets/${avdSubnetName}'

@description('AVD subnet name')
output avdSubnetName string = avdSubnetName

@description('Bastion subnet ID (if created)')
output bastionSubnetId string = enableBastionSubnet ? '${vnet.id}/subnets/AzureBastionSubnet' : ''
