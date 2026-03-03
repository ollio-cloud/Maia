// ============================================================================
// FSLogix Storage Account Module
// Author: Maia Azure Solutions Architect
// Version: 1.0.0
// Description: Reusable module for Premium FileStorage account
// ============================================================================

@description('Name of the storage account')
param storageAccountName string

@description('Azure region')
param location string

@description('Storage account SKU')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
param sku string = 'Premium_LRS'

@description('Enable Azure AD Kerberos authentication')
param enableAzureADKerberos bool = true

@description('Azure AD Tenant ID')
param tenantId string = ''

@description('Azure AD Tenant name')
param tenantName string = ''

@description('Minimum TLS version')
@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
param minimumTlsVersion string = 'TLS1_2'

@description('Tags for the storage account')
param tags object = {}

@description('Enable network restrictions (VNet service endpoint)')
param enableNetworkRestrictions bool = true

@description('Subnet resource ID for VNet service endpoint access')
param allowedSubnetId string = ''

@description('Additional IP addresses to allow (e.g., admin IPs)')
param allowedIpAddresses array = []

// ============================================================================
// Resources
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'FileStorage'
  sku: {
    name: sku
  }
  properties: {
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    largeFileSharesState: 'Enabled'
    azureFilesIdentityBasedAuthentication: enableAzureADKerberos ? {
      directoryServiceOptions: 'AADKERB'
      activeDirectoryProperties: {
        domainName: tenantName
        domainGuid: tenantId
      }
    } : null
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enableNetworkRestrictions ? 'Deny' : 'Allow'
      ipRules: [for ip in allowedIpAddresses: {
        value: ip
        action: 'Allow'
      }]
      virtualNetworkRules: enableNetworkRestrictions && !empty(allowedSubnetId) ? [
        {
          id: allowedSubnetId
          action: 'Allow'
        }
      ] : []
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Storage account resource ID')
output storageAccountId string = storageAccount.id

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Primary file endpoint')
output primaryFileEndpoint string = storageAccount.properties.primaryEndpoints.file

@description('Storage account key')
#disable-next-line outputs-should-not-contain-secrets
output storageAccountKey string = storageAccount.listKeys().keys[0].value
