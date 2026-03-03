// ============================================================================
// FSLogix VM Extension - Bicep Parameters
// Environment: Production
// Last Updated: 2025-12-17
// ============================================================================

using 'fslogix-vm-extension.bicep'

// VM Configuration
param vmNames = [
  'pauseisavd-0'
  'pauseisavd-1'
]
param location = 'australiasoutheast'

// Storage Configuration
param storageAccountName = 'pauseisfslogix001'
param fileShareName = 'fslogix-profiles'

// FSLogix Settings
param profileSizeMB = 30720  // 30 GB

// Authentication
param useStorageAccountKey = false  // Use Azure AD Kerberos by default
param storageAccountKey = ''  // Only needed if useStorageAccountKey = true

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
  ManagedBy: 'Bicep'
}
