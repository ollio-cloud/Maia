// ============================================================================
// FSLogix Storage Account - Bicep Template
// Author: Maia Azure Solutions Architect
// Version: 1.0.0
// Description: Deploys Premium FileStorage account with Azure AD Kerberos
// ============================================================================

@description('Name of the storage account for FSLogix profiles')
param storageAccountName string = 'pauseisfslogix001'

@description('Azure region for deployment')
param location string = 'australiasoutheast'

@description('Name of the file share for FSLogix profiles')
param fileShareName string = 'fslogix-profiles'

@description('Quota for the file share in GB')
@minValue(100)
@maxValue(102400)
param fileShareQuotaGB int = 256

@description('Storage account SKU')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
param storageAccountSku string = 'Premium_LRS'

@description('Enable Azure AD Kerberos authentication for Azure Files')
param enableAzureADKerberos bool = true

@description('Azure AD Tenant ID for Kerberos authentication')
param azureADTenantId string = ''

@description('Azure AD Tenant name (e.g., contoso.onmicrosoft.com)')
param azureADTenantName string = ''

@description('Object ID of the Azure AD group for AVD users (for RBAC)')
param avdUsersGroupObjectId string = ''

@description('Object ID of the Azure AD group for AVD admins (for RBAC)')
param avdAdminsGroupObjectId string = ''

@description('Enable soft delete for file shares')
param enableSoftDelete bool = true

@description('Soft delete retention period in days')
@minValue(1)
@maxValue(365)
param softDeleteRetentionDays int = 7

@description('Tags to apply to resources')
param tags object = {
  Environment: 'Production'
  Application: 'AVD'
  Component: 'FSLogix'
  ManagedBy: 'Bicep'
}

// ============================================================================
// Variables
// ============================================================================

var storageFileDataSMBShareContributorRoleId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
var storageFileDataSMBShareElevatedContributorRoleId = 'a7264617-510b-434b-a828-9731dc254ea7'

// ============================================================================
// Resources
// ============================================================================

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'FileStorage'
  sku: {
    name: storageAccountSku
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    largeFileSharesState: 'Enabled'
    azureFilesIdentityBasedAuthentication: enableAzureADKerberos ? {
      directoryServiceOptions: 'AADKERB'
      activeDirectoryProperties: {
        domainName: azureADTenantName
        domainGuid: azureADTenantId
      }
    } : null
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// File Services
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: enableSoftDelete
      days: softDeleteRetentionDays
    }
  }
}

// File Share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileServices
  name: fileShareName
  properties: {
    shareQuota: fileShareQuotaGB
    enabledProtocols: 'SMB'
    accessTier: 'Premium'
  }
}

// RBAC - AVD Users (Storage File Data SMB Share Contributor)
resource avdUsersRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(avdUsersGroupObjectId)) {
  name: guid(fileShare.id, avdUsersGroupObjectId, storageFileDataSMBShareContributorRoleId)
  scope: fileShare
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataSMBShareContributorRoleId)
    principalId: avdUsersGroupObjectId
    principalType: 'Group'
  }
}

// RBAC - AVD Admins (Storage File Data SMB Share Elevated Contributor)
resource avdAdminsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(avdAdminsGroupObjectId)) {
  name: guid(fileShare.id, avdAdminsGroupObjectId, storageFileDataSMBShareElevatedContributorRoleId)
  scope: fileShare
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataSMBShareElevatedContributorRoleId)
    principalId: avdAdminsGroupObjectId
    principalType: 'Group'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Storage account resource ID')
output storageAccountId string = storageAccount.id

@description('File share name')
output fileShareName string = fileShare.name

@description('File share UNC path')
output fileShareUNC string = '\\\\${storageAccount.name}.file.core.windows.net\\${fileShareName}'

@description('Storage account primary file endpoint')
output primaryFileEndpoint string = storageAccount.properties.primaryEndpoints.file

@description('Storage account key (for fallback authentication)')
#disable-next-line outputs-should-not-contain-secrets
output storageAccountKey string = storageAccount.listKeys().keys[0].value
