// ============================================================================
// RBAC Role Assignment Module
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Reusable module for RBAC on file shares
// ============================================================================

@description('Storage account name')
param storageAccountName string

@description('File share name')
param fileShareName string

@description('Principal (user/group) Object ID')
param principalId string

@description('Principal type')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'Group'

@description('Role to assign')
@allowed([
  'StorageFileDataSMBShareContributor'
  'StorageFileDataSMBShareElevatedContributor'
  'StorageFileDataSMBShareReader'
])
param role string

// ============================================================================
// Variables
// ============================================================================

var roleDefinitionIds = {
  StorageFileDataSMBShareContributor: '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
  StorageFileDataSMBShareElevatedContributor: 'a7264617-510b-434b-a828-9731dc254ea7'
  StorageFileDataSMBShareReader: 'aba4ae5f-2193-4029-9191-0cb91df5e314'
}

// ============================================================================
// Existing Resources
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' existing = {
  parent: fileServices
  name: fileShareName
}

// ============================================================================
// Resources
// ============================================================================

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(fileShare.id, principalId, roleDefinitionIds[role])
  scope: fileShare
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds[role])
    principalId: principalId
    principalType: principalType
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Role assignment ID')
output roleAssignmentId string = roleAssignment.id

@description('Assigned role')
output assignedRole string = role
