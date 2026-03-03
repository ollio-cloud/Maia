// ============================================================================
// FSLogix Complete Deployment - Bicep Parameters
// Environment: Production - pauseisavdpool01
// Last Updated: 2025-12-17
// ============================================================================

using 'fslogix-complete.bicep'

// Storage Configuration
param storageAccountName = 'pauseisfslogix001'
param location = 'australiasoutheast'
param fileShareName = 'fslogix-profiles'
param fileShareQuotaGB = 256

// VM Configuration
param vmNames = [
  'pauseisavd-0'
  'pauseisavd-1'
]

// FSLogix Settings
param profileSizeMB = 30720  // 30 GB

// Azure AD Configuration
param enableAzureADKerberos = true
param azureADTenantId = 'YOUR_TENANT_ID_HERE'  // Get from: (Get-AzContext).Tenant.Id
param azureADTenantName = 'YOUR_TENANT.onmicrosoft.com'  // Get from: (Get-AzTenant).DefaultDomain

// RBAC - Azure AD Group Object IDs
param avdUsersGroupObjectId = 'YOUR_AVD_USERS_GROUP_OBJECT_ID'  // Get from: (Get-AzADGroup -DisplayName "AVD-Users").Id
param avdAdminsGroupObjectId = 'YOUR_AVD_ADMINS_GROUP_OBJECT_ID'  // Get from: (Get-AzADGroup -DisplayName "AVD-Admins").Id

// FSLogix Behavior
param enableOfficeContainer = true
param deleteLocalProfileWhenVHDApplies = true
param preventLoginWithTempProfile = true
param preventLoginWithFailure = false

// Tags
param tags = {
  Environment: 'Production'
  Application: 'AVD'
  Component: 'FSLogix'
  HostPool: 'pauseisavdpool01'
  CostCenter: 'IT'
  Owner: 'AVD Team'
  ManagedBy: 'Bicep'
}
