// ============================================================================
// AVD Session Host Deployment - Complete Orchestrator
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Deploys new AVD session host with FSLogix configuration
// Target: pauseisavd-1 with Standard_E8s_v5
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('VM name for the session host')
param vmName string = 'pauseisavd-1'

@description('Azure region')
param location string = 'australiasoutheast'

@description('VM size')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
  'Standard_E2s_v5'
  'Standard_E4s_v5'
  'Standard_E8s_v5'
  'Standard_E16s_v5'
  'Standard_B2ms'
  'Standard_B2s'
])
param vmSize string = 'Standard_D4s_v5'

@description('Admin username')
param adminUsername string = 'avdadmin'

@description('Admin password')
@secure()
param adminPassword string

@description('Subnet resource ID for the VM NIC')
param subnetId string

@description('AVD Host Pool name')
param hostPoolName string = 'pauseisavdpool01'

@description('AVD Host Pool registration token (get from portal or generate)')
@secure()
param hostPoolToken string

@description('OS disk type')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskType string = 'Premium_LRS'

@description('OS disk size in GB')
param osDiskSizeGB int = 128

@description('Enable Azure AD join')
param enableAzureADJoin bool = true

@description('Enable Intune enrollment')
param enableIntune bool = true

@description('Availability Zone (1, 2, 3, or empty for regions without zone support)')
param availabilityZone string = ''

@description('Windows image reference')
param imageReference object = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-avd'
  version: 'latest'
}

// FSLogix Configuration Parameters
@description('Enable FSLogix configuration')
param enableFSLogix bool = true

@description('Storage account name for FSLogix')
param fslogixStorageAccountName string = 'pauseisfslogix001'

@description('File share name for profiles')
param fslogixFileShareName string = 'fslogix-profiles'

@description('Profile size in MB')
param fslogixProfileSizeMB int = 30720

@description('Enable Office Container')
param fslogixEnableOfficeContainer bool = true

@description('Delete local profile when VHD applies')
param fslogixDeleteLocalProfile bool = true

@description('Prevent login with temp profile')
param fslogixPreventTempProfile bool = true

@description('Prevent login on failure')
param fslogixPreventLoginOnFailure bool = false

@description('Use storage account key instead of Azure AD Kerberos')
param fslogixUseStorageKey bool = false

@description('Tags for all resources')
param tags object = {
  Environment: 'Production'
  Application: 'AVD'
  HostPool: 'pauseisavdpool01'
  Component: 'SessionHost'
  ManagedBy: 'Bicep'
}

// ============================================================================
// Module 1: Session Host VM
// ============================================================================

module sessionHost 'modules/session-host.bicep' = {
  name: 'deploy-session-host-${vmName}'
  params: {
    vmName: vmName
    location: location
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: subnetId
    osDiskType: osDiskType
    osDiskSizeGB: osDiskSizeGB
    imageReference: imageReference
    hostPoolName: hostPoolName
    hostPoolToken: hostPoolToken
    enableAzureADJoin: enableAzureADJoin
    enableIntune: enableIntune
    availabilityZone: availabilityZone
    tags: tags
  }
}

// ============================================================================
// Module 2: FSLogix Extension (optional)
// ============================================================================

module fslogixExtension 'modules/fslogix-extension.bicep' = if (enableFSLogix) {
  name: 'deploy-fslogix-${vmName}'
  params: {
    vmName: vmName
    location: location
    storageAccountName: fslogixStorageAccountName
    fileShareName: fslogixFileShareName
    profileSizeMB: fslogixProfileSizeMB
    enableOfficeContainer: fslogixEnableOfficeContainer
    deleteLocalProfile: fslogixDeleteLocalProfile
    preventTempProfile: fslogixPreventTempProfile
    preventLoginOnFailure: fslogixPreventLoginOnFailure
    useStorageKey: fslogixUseStorageKey
    tags: tags
  }
  dependsOn: [
    sessionHost
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('VM resource ID')
output vmId string = sessionHost.outputs.vmId

@description('VM name')
output vmName string = sessionHost.outputs.vmName

@description('VM private IP')
output privateIpAddress string = sessionHost.outputs.privateIpAddress

@description('VM principal ID')
output principalId string = sessionHost.outputs.principalId

@description('Host pool name')
output hostPoolName string = hostPoolName

@description('FSLogix configured')
output fslogixConfigured bool = enableFSLogix
