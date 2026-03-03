// ============================================================================
// AVD Session Host VM Module
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Deploys AVD session host VM with host pool registration
// ============================================================================

@description('VM name')
param vmName string

@description('Azure region')
param location string

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
param vmSize string = 'Standard_D2s_v3'

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('Subnet resource ID')
param subnetId string

@description('OS disk type')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskType string = 'Premium_LRS'

@description('OS disk size in GB')
param osDiskSizeGB int = 128

@description('Image reference')
param imageReference object = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-avd'
  version: 'latest'
}

@description('AVD Host Pool name')
param hostPoolName string

@description('AVD Host Pool registration token')
@secure()
param hostPoolToken string

@description('Enable Azure AD join')
param enableAzureADJoin bool = true

@description('Enable Intune enrollment')
param enableIntune bool = true

@description('Availability Zone (1, 2, 3, or empty for regions without zone support)')
param availabilityZone string = ''

@description('Tags for the VM')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

var nicName = '${vmName}-nic'

// ============================================================================
// Resources
// ============================================================================

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  tags: tags
  zones: !empty(availabilityZone) ? [availabilityZone] : null
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: osDiskSizeGB
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    licenseType: 'Windows_Client'
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// Azure AD Join Extension
resource aadJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = if (enableAzureADJoin) {
  parent: vm
  name: 'AADLoginForWindows'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: enableIntune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } : {}
  }
}

// AVD Agent Extension (DSC)
resource avdAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'Microsoft.PowerShell.DSC'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      // Official Microsoft AVD DSC artifact URL - same across all Azure clouds
      #disable-next-line no-hardcoded-env-urls
      modulesUrl: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPoolName
        registrationInfoTokenCredential: {
          UserName: 'YOURPLACEHODLER'
          Password: 'PrivateSettingsRef:RegistrationInfoToken'
        }
        aadJoin: enableAzureADJoin
        UseAgentDownloadEndpoint: true
        aadJoinPreview: false
      }
    }
    protectedSettings: {
      Items: {
        RegistrationInfoToken: hostPoolToken
      }
    }
  }
  dependsOn: [
    aadJoinExtension
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('VM resource ID')
output vmId string = vm.id

@description('VM name')
output vmName string = vm.name

@description('VM private IP')
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('VM principal ID (for RBAC)')
output principalId string = vm.identity.principalId
