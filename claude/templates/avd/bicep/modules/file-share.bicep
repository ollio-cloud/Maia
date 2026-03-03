// ============================================================================
// Azure Files Share Module
// Author: Maia Azure Solutions Architect
// Version: 1.0.0
// Description: Reusable module for Azure Files share with soft delete
// ============================================================================

@description('Storage account name (existing)')
param storageAccountName string

@description('Name of the file share')
param fileShareName string

@description('Quota in GB')
@minValue(100)
@maxValue(102400)
param shareQuotaGB int

@description('Access tier')
@allowed([
  'Premium'
  'Hot'
  'Cool'
  'TransactionOptimized'
])
param accessTier string = 'Premium'

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention days')
@minValue(1)
@maxValue(365)
param softDeleteRetentionDays int = 7

// ============================================================================
// Resources
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

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

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileServices
  name: fileShareName
  properties: {
    shareQuota: shareQuotaGB
    enabledProtocols: 'SMB'
    accessTier: accessTier
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('File share resource ID')
output fileShareId string = fileShare.id

@description('File share name')
output fileShareName string = fileShare.name

@description('File share UNC path')
output fileShareUNC string = '\\\\${storageAccountName}.file.${environment().suffixes.storage}\\${fileShareName}'
