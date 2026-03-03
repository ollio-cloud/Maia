// ============================================================================
// AVD Application Group Module
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Creates AVD Application Group and assigns users
// ============================================================================

@description('Application group name')
param appGroupName string

@description('Azure region')
param location string

@description('Host pool resource ID')
param hostPoolId string

@description('Friendly name')
param friendlyName string = ''

@description('Description')
param appGroupDescription string = 'AVD Application Group'

@description('Application group type')
@allowed([
  'Desktop'
  'RemoteApp'
])
param appGroupType string = 'Desktop'

@description('User group Object IDs to assign')
param userGroupObjectIds array = []

@description('Tags')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

// Desktop Virtualization User role definition ID
var desktopVirtualizationUserRoleId = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'

// ============================================================================
// Resources
// ============================================================================

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: appGroupName
  location: location
  tags: tags
  properties: {
    friendlyName: empty(friendlyName) ? appGroupName : friendlyName
    description: appGroupDescription
    applicationGroupType: appGroupType
    hostPoolArmPath: hostPoolId
  }
}

// Role assignments for user groups
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (groupId, i) in userGroupObjectIds: if (!empty(groupId)) {
  name: guid(appGroup.id, groupId, desktopVirtualizationUserRoleId)
  scope: appGroup
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', desktopVirtualizationUserRoleId)
    principalId: groupId
    principalType: 'Group'
  }
}]

// ============================================================================
// Outputs
// ============================================================================

@description('Application group resource ID')
output appGroupId string = appGroup.id

@description('Application group name')
output appGroupName string = appGroup.name

@description('Application group type')
output appGroupType string = appGroupType
