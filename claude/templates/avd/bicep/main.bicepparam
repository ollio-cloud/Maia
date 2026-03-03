// ============================================================================
// FSLogix Modular Deployment - Parameters
// Environment: Production - pauseisavdpool01
// ============================================================================

using 'main.bicep'

// Storage Configuration
param storageAccountName = 'pauseisfslogix001'
param location = 'australiasoutheast'
param fileShareName = 'fslogix-profiles'
param fileShareQuotaGB = 256
param storageAccountSku = 'Premium_LRS'

// VM Configuration
param vmNames = [
  'pauseisavd-0'
  'pauseisavd-1'
]

// FSLogix Settings
param profileSizeMB = 30720
param enableOfficeContainer = true
param deleteLocalProfile = true
param preventTempProfile = true
param preventLoginOnFailure = false

// Azure AD Configuration
param enableAzureADKerberos = true
param azureADTenantId = 'YOUR_TENANT_ID_HERE'
param azureADTenantName = 'YOUR_TENANT.onmicrosoft.com'

// RBAC
param avdUsersGroupObjectId = 'YOUR_AVD_USERS_GROUP_OBJECT_ID'
param avdAdminsGroupObjectId = 'YOUR_AVD_ADMINS_GROUP_OBJECT_ID'

// Authentication
param useStorageKey = false

// Tags
param tags = {
  Environment: 'Production'
  Application: 'AVD'
  Component: 'FSLogix'
  HostPool: 'pauseisavdpool01'
  CostCenter: 'IT'
  Owner: 'AVD Team'
  ManagedBy: 'Bicep-Modular'
}
