// ============================================================================
// AVD Workspace Module
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Creates AVD Workspace and links application groups
// ============================================================================

@description('Workspace name')
param workspaceName string

@description('Azure region')
param location string

@description('Friendly name')
param friendlyName string = ''

@description('Description')
param workspaceDescription string = 'AVD Workspace'

@description('Application group resource IDs to link')
param applicationGroupIds array = []

@description('Tags')
param tags object = {}

// ============================================================================
// Resources
// ============================================================================

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    friendlyName: empty(friendlyName) ? workspaceName : friendlyName
    description: workspaceDescription
    applicationGroupReferences: applicationGroupIds
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Workspace resource ID')
output workspaceId string = workspace.id

@description('Workspace name')
output workspaceName string = workspace.name
