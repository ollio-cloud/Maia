// ============================================================================
// FSLogix Modular Deployment - Main Orchestrator
// Author: Maia Azure Solutions Architect
// Version: 1.0.0
// Description: Orchestrates modular FSLogix deployment
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Storage account name')
param storageAccountName string = 'pauseisfslogix001'

@description('Azure region')
param location string = 'australiasoutheast'

@description('File share name')
param fileShareName string = 'fslogix-profiles'

@description('File share quota in GB')
@minValue(100)
@maxValue(102400)
param fileShareQuotaGB int = 256

@description('Storage account SKU')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
param storageAccountSku string = 'Premium_LRS'

@description('VM names to configure')
param vmNames array = [
  'pauseisavd-0'
  'pauseisavd-1'
]

@description('Profile size in MB')
param profileSizeMB int = 30720

@description('Enable Azure AD Kerberos')
param enableAzureADKerberos bool = true

@description('Azure AD Tenant ID')
param azureADTenantId string = ''

@description('Azure AD Tenant name')
param azureADTenantName string = ''

@description('AVD Users group Object ID')
param avdUsersGroupObjectId string = ''

@description('AVD Admins group Object ID')
param avdAdminsGroupObjectId string = ''

@description('Enable Office Container')
param enableOfficeContainer bool = true

@description('Delete local profile when VHD applies')
param deleteLocalProfile bool = true

@description('Prevent login with temp profile')
param preventTempProfile bool = true

@description('Prevent login on FSLogix failure')
param preventLoginOnFailure bool = false

@description('Use storage account key instead of Azure AD Kerberos')
param useStorageKey bool = false

@description('Tags for all resources')
param tags object = {
  Environment: 'Production'
  Application: 'AVD'
  Component: 'FSLogix'
  ManagedBy: 'Bicep-Modular'
}

// ============================================================================
// Module 1: Storage Account
// ============================================================================

module storageAccount 'modules/storage-account.bicep' = {
  name: 'deploy-storage-account'
  params: {
    storageAccountName: storageAccountName
    location: location
    sku: storageAccountSku
    enableAzureADKerberos: enableAzureADKerberos
    tenantId: azureADTenantId
    tenantName: azureADTenantName
    tags: tags
  }
}

// ============================================================================
// Module 2: File Share
// ============================================================================

module fileShare 'modules/file-share.bicep' = {
  name: 'deploy-file-share'
  params: {
    storageAccountName: storageAccount.outputs.storageAccountName
    fileShareName: fileShareName
    shareQuotaGB: fileShareQuotaGB
    accessTier: 'Premium'
    enableSoftDelete: true
    softDeleteRetentionDays: 7
  }
  dependsOn: [
    storageAccount
  ]
}

// ============================================================================
// Module 3: RBAC - AVD Users
// ============================================================================

module rbacUsers 'modules/rbac-assignment.bicep' = if (!empty(avdUsersGroupObjectId)) {
  name: 'deploy-rbac-users'
  params: {
    storageAccountName: storageAccountName
    fileShareName: fileShareName
    principalId: avdUsersGroupObjectId
    principalType: 'Group'
    role: 'StorageFileDataSMBShareContributor'
  }
  dependsOn: [
    fileShare
  ]
}

// ============================================================================
// Module 4: RBAC - AVD Admins
// ============================================================================

module rbacAdmins 'modules/rbac-assignment.bicep' = if (!empty(avdAdminsGroupObjectId)) {
  name: 'deploy-rbac-admins'
  params: {
    storageAccountName: storageAccountName
    fileShareName: fileShareName
    principalId: avdAdminsGroupObjectId
    principalType: 'Group'
    role: 'StorageFileDataSMBShareElevatedContributor'
  }
  dependsOn: [
    fileShare
  ]
}

// ============================================================================
// Module 5: FSLogix VM Extensions (loop)
// ============================================================================

module fslogixExtensions 'modules/fslogix-extension.bicep' = [for vmName in vmNames: {
  name: 'deploy-fslogix-${vmName}'
  params: {
    vmName: vmName
    location: location
    storageAccountName: storageAccount.outputs.storageAccountName
    fileShareName: fileShare.outputs.fileShareName
    profileSizeMB: profileSizeMB
    enableOfficeContainer: enableOfficeContainer
    deleteLocalProfile: deleteLocalProfile
    preventTempProfile: preventTempProfile
    preventLoginOnFailure: preventLoginOnFailure
    useStorageKey: useStorageKey
    storageAccountKey: useStorageKey ? storageAccount.outputs.storageAccountKey : ''
    tags: tags
  }
  dependsOn: [
    fileShare
    rbacUsers
    rbacAdmins
  ]
}]

// ============================================================================
// Outputs
// ============================================================================

@description('Storage account name')
output storageAccountName string = storageAccount.outputs.storageAccountName

@description('Storage account ID')
output storageAccountId string = storageAccount.outputs.storageAccountId

@description('File share UNC path')
output fileShareUNC string = fileShare.outputs.fileShareUNC

@description('Configured VMs')
output configuredVMs array = [for (vmName, i) in vmNames: {
  name: vmName
  provisioningState: fslogixExtensions[i].outputs.provisioningState
}]

@description('Authentication method')
output authenticationMethod string = enableAzureADKerberos ? 'Azure AD Kerberos' : 'Storage Account Key'

@description('Primary file endpoint')
output primaryFileEndpoint string = storageAccount.outputs.primaryFileEndpoint
