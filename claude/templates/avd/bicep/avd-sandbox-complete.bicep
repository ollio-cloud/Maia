// ============================================================================
// AVD Sandbox - Complete Deployment
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Deploys complete AVD environment from scratch for testing
// Includes: VNet, Host Pool, App Group, Workspace, Storage, Session Host
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Naming Parameters
// ============================================================================

@description('Environment prefix (e.g., test, sandbox, dev)')
param environmentPrefix string = 'test'

@description('Project/workload name')
param projectName string = 'avd'

@description('Azure region')
param location string = 'australiasoutheast'

// ============================================================================
// Network Parameters
// ============================================================================

@description('VNet address prefix')
param vnetAddressPrefix string = '10.100.0.0/16'

@description('AVD subnet address prefix')
param avdSubnetPrefix string = '10.100.1.0/24'

@description('Enable Azure Bastion subnet')
param enableBastionSubnet bool = false

// ============================================================================
// Host Pool Parameters
// ============================================================================

@description('Host pool type')
@allowed([
  'Personal'
  'Pooled'
])
param hostPoolType string = 'Pooled'

@description('Load balancer type')
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param loadBalancerType string = 'BreadthFirst'

@description('Max sessions per host')
param maxSessionLimit int = 10

@description('Start VM on connect')
param startVMOnConnect bool = true

// ============================================================================
// Session Host Parameters
// ============================================================================

@description('Number of session hosts to deploy')
@minValue(1)
@maxValue(10)
param sessionHostCount int = 1

@description('Session host VM size')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
  'Standard_E2s_v5'
  'Standard_E4s_v5'
  'Standard_E8s_v5'
  'Standard_B2ms'
  'Standard_B2s'
])
param vmSize string = 'Standard_D2s_v3'

@description('Admin username')
param adminUsername string = 'avdadmin'

@description('Admin password')
@secure()
param adminPassword string

@description('OS disk type')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskType string = 'Premium_LRS'

@description('OS disk size in GB')
param osDiskSizeGB int = 128

@description('Windows image')
param imageReference object = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-avd'
  version: 'latest'
}

@description('Enable Azure AD join')
param enableAzureADJoin bool = true

@description('Enable Intune enrollment')
param enableIntune bool = true

// ============================================================================
// FSLogix Parameters
// ============================================================================

@description('Enable FSLogix')
param enableFSLogix bool = true

@description('File share quota in GB')
param fileShareQuotaGB int = 256

@description('Profile size in MB')
param profileSizeMB int = 30720

@description('Enable Office Container')
param enableOfficeContainer bool = true

// ============================================================================
// Azure AD Parameters
// ============================================================================

@description('Azure AD Tenant ID (for Azure Files Kerberos)')
param azureADTenantId string = ''

@description('Azure AD Tenant name (e.g., contoso.onmicrosoft.com)')
param azureADTenantName string = ''

@description('AVD Users group Object ID (for RBAC)')
param avdUsersGroupObjectId string = ''

@description('AVD Admins group Object ID (for elevated access)')
param avdAdminsGroupObjectId string = ''

// ============================================================================
// Tags
// ============================================================================

@description('Tags for all resources')
param tags object = {
  Environment: environmentPrefix
  Application: 'AVD'
  ManagedBy: 'Bicep'
  DeploymentType: 'Sandbox'
}

// ============================================================================
// Variables - Resource Names
// ============================================================================

var resourceNames = {
  vnet: '${environmentPrefix}-${projectName}-vnet'
  hostPool: '${environmentPrefix}-${projectName}-hp'
  appGroup: '${environmentPrefix}-${projectName}-dag'
  workspace: '${environmentPrefix}-${projectName}-ws'
  storageAccount: replace('${environmentPrefix}${projectName}fslogix', '-', '')
  fileShare: 'fslogix-profiles'
  vmPrefix: '${environmentPrefix}${projectName}'
}

// ============================================================================
// Module 1: Virtual Network
// ============================================================================

module vnet 'modules/virtual-network.bicep' = {
  name: 'deploy-vnet'
  params: {
    vnetName: resourceNames.vnet
    location: location
    vnetAddressPrefix: vnetAddressPrefix
    avdSubnetName: 'snet-avd'
    avdSubnetPrefix: avdSubnetPrefix
    enableBastionSubnet: enableBastionSubnet
    tags: tags
  }
}

// ============================================================================
// Module 2: Host Pool
// ============================================================================

module hostPool 'modules/host-pool.bicep' = {
  name: 'deploy-hostpool'
  params: {
    hostPoolName: resourceNames.hostPool
    location: location
    friendlyName: '${environmentPrefix} AVD Host Pool'
    hostPoolDescription: 'Sandbox/Test AVD Host Pool'
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    maxSessionLimit: maxSessionLimit
    startVMOnConnect: startVMOnConnect
    validationEnvironment: true  // Sandbox is validation environment
    tokenExpirationHours: 24
    tags: tags
  }
}

// ============================================================================
// Module 3: Application Group (Desktop)
// ============================================================================

module appGroup 'modules/application-group.bicep' = {
  name: 'deploy-appgroup'
  params: {
    appGroupName: resourceNames.appGroup
    location: location
    hostPoolId: hostPool.outputs.hostPoolId
    friendlyName: '${environmentPrefix} Desktop'
    appGroupDescription: 'Desktop Application Group'
    appGroupType: 'Desktop'
    userGroupObjectIds: !empty(avdUsersGroupObjectId) ? [avdUsersGroupObjectId] : []
    tags: tags
  }
}

// ============================================================================
// Module 4: Workspace
// ============================================================================

module workspace 'modules/workspace.bicep' = {
  name: 'deploy-workspace'
  params: {
    workspaceName: resourceNames.workspace
    location: location
    friendlyName: '${environmentPrefix} Workspace'
    workspaceDescription: 'AVD Workspace for ${environmentPrefix} environment'
    applicationGroupIds: [
      appGroup.outputs.appGroupId
    ]
    tags: tags
  }
}

// ============================================================================
// Module 5: FSLogix Storage (conditional)
// ============================================================================

module storageAccount 'modules/storage-account.bicep' = if (enableFSLogix) {
  name: 'deploy-storage'
  params: {
    storageAccountName: resourceNames.storageAccount
    location: location
    sku: 'Premium_LRS'
    enableAzureADKerberos: !empty(azureADTenantId)
    tenantId: azureADTenantId
    tenantName: azureADTenantName
    tags: tags
  }
}

module fileShare 'modules/file-share.bicep' = if (enableFSLogix) {
  name: 'deploy-fileshare'
  params: {
    storageAccountName: storageAccount!.outputs.storageAccountName
    fileShareName: resourceNames.fileShare
    shareQuotaGB: fileShareQuotaGB
    accessTier: 'Premium'
    enableSoftDelete: true
    softDeleteRetentionDays: 7
  }
}

// RBAC for FSLogix file share
module rbacUsers 'modules/rbac-assignment.bicep' = if (enableFSLogix && !empty(avdUsersGroupObjectId)) {
  name: 'deploy-rbac-users'
  params: {
    storageAccountName: resourceNames.storageAccount
    fileShareName: resourceNames.fileShare
    principalId: avdUsersGroupObjectId
    principalType: 'Group'
    role: 'StorageFileDataSMBShareContributor'
  }
  dependsOn: [
    fileShare
  ]
}

module rbacAdmins 'modules/rbac-assignment.bicep' = if (enableFSLogix && !empty(avdAdminsGroupObjectId)) {
  name: 'deploy-rbac-admins'
  params: {
    storageAccountName: resourceNames.storageAccount
    fileShareName: resourceNames.fileShare
    principalId: avdAdminsGroupObjectId
    principalType: 'Group'
    role: 'StorageFileDataSMBShareElevatedContributor'
  }
  dependsOn: [
    fileShare
  ]
}

// ============================================================================
// Module 6: Session Hosts
// ============================================================================

// Availability zone lookup array for type safety
var availabilityZones = ['1', '2', '3']

module sessionHosts 'modules/session-host.bicep' = [for i in range(0, sessionHostCount): {
  name: 'deploy-sessionhost-${i}'
  params: {
    vmName: '${resourceNames.vmPrefix}-${i}'
    location: location
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: vnet.outputs.avdSubnetId
    osDiskType: osDiskType
    osDiskSizeGB: osDiskSizeGB
    imageReference: imageReference
    hostPoolName: hostPool.outputs.hostPoolName
    hostPoolToken: hostPool.outputs.registrationToken
    enableAzureADJoin: enableAzureADJoin
    enableIntune: enableIntune
    availabilityZone: availabilityZones[i % 3]  // Distribute across zones
    tags: union(tags, {
      SessionHost: '${resourceNames.vmPrefix}-${i}'
      HostPool: resourceNames.hostPool
    })
  }
}]

// ============================================================================
// Module 7: FSLogix Extensions
// ============================================================================

module fslogixExtensions 'modules/fslogix-extension.bicep' = [for i in range(0, sessionHostCount): if (enableFSLogix) {
  name: 'deploy-fslogix-${i}'
  params: {
    vmName: '${resourceNames.vmPrefix}-${i}'
    location: location
    storageAccountName: storageAccount!.outputs.storageAccountName
    fileShareName: resourceNames.fileShare
    profileSizeMB: profileSizeMB
    enableOfficeContainer: enableOfficeContainer
    deleteLocalProfile: true
    preventTempProfile: true
    preventLoginOnFailure: false
    useStorageKey: empty(azureADTenantId)  // Use key if no Azure AD Kerberos
    storageAccountKey: empty(azureADTenantId) ? storageAccount!.outputs.storageAccountKey : ''
    tags: tags
  }
  dependsOn: [
    sessionHosts
    fileShare
  ]
}]

// ============================================================================
// Outputs
// ============================================================================

@description('Resource names')
output resourceNames object = resourceNames

@description('VNet ID')
output vnetId string = vnet.outputs.vnetId

@description('Subnet ID')
output subnetId string = vnet.outputs.avdSubnetId

@description('Host Pool name')
output hostPoolName string = hostPool.outputs.hostPoolName

@description('Host Pool ID')
output hostPoolId string = hostPool.outputs.hostPoolId

@description('Application Group ID')
output appGroupId string = appGroup.outputs.appGroupId

@description('Workspace ID')
output workspaceId string = workspace.outputs.workspaceId

@description('Storage Account name')
output storageAccountName string = enableFSLogix ? storageAccount!.outputs.storageAccountName : 'N/A'

@description('File Share UNC')
output fileShareUNC string = enableFSLogix ? fileShare!.outputs.fileShareUNC : 'N/A'

@description('Session Host VMs')
output sessionHostVMs array = [for i in range(0, sessionHostCount): {
  name: '${resourceNames.vmPrefix}-${i}'
  privateIp: sessionHosts[i].outputs.privateIpAddress
}]

@description('AVD Web Client URL')
output avdWebClientUrl string = 'https://client.wvd.microsoft.com/arm/webclient/index.html'

@description('Deployment summary')
output summary object = {
  environment: environmentPrefix
  location: location
  hostPool: resourceNames.hostPool
  sessionHostCount: sessionHostCount
  vmSize: vmSize
  fslogixEnabled: enableFSLogix
  azureADJoin: enableAzureADJoin
}
