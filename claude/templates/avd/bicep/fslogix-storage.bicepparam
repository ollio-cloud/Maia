// ============================================================================
// FSLogix Storage Account - Bicep Parameters
// Environment: Production
// Last Updated: 2025-12-17
// ============================================================================

using 'fslogix-storage.bicep'

// Storage Configuration
param storageAccountName = 'pauseisfslogix001'
param location = 'australiasoutheast'
param fileShareName = 'fslogix-profiles'
param fileShareQuotaGB = 256
param storageAccountSku = 'Premium_LRS'

// Azure AD Kerberos Configuration
param enableAzureADKerberos = true
param azureADTenantId = 'YOUR_TENANT_ID_HERE'
param azureADTenantName = 'YOUR_TENANT.onmicrosoft.com'

// RBAC Configuration
param avdUsersGroupObjectId = 'YOUR_AVD_USERS_GROUP_OBJECT_ID'
param avdAdminsGroupObjectId = 'YOUR_AVD_ADMINS_GROUP_OBJECT_ID'

// Soft Delete
param enableSoftDelete = true
param softDeleteRetentionDays = 7

// Tags
param tags = {
  Environment: 'Production'
  Application: 'AVD'
  Component: 'FSLogix'
  ManagedBy: 'Bicep'
}
