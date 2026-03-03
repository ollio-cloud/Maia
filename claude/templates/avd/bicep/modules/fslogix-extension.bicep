// ============================================================================
// FSLogix VM Extension Module
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Reusable module for FSLogix installation on single VM
// ============================================================================

@description('VM name to configure')
param vmName string

@description('Azure region')
param location string

@description('Storage account name for FSLogix')
param storageAccountName string

@description('File share name')
param fileShareName string

@description('Profile size in MB')
param profileSizeMB int = 30720

@description('Enable Office Container')
param enableOfficeContainer bool = true

@description('Delete local profile when VHD applies')
param deleteLocalProfile bool = true

@description('Prevent login with temp profile')
param preventTempProfile bool = true

@description('Prevent login on failure')
param preventLoginOnFailure bool = false

@description('Storage account key (only if not using Azure AD Kerberos)')
@secure()
param storageAccountKey string = ''

@description('Use storage key instead of Azure AD Kerberos')
param useStorageKey bool = false

@description('Tags for the extension')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

var storageEndpointSuffix = environment().suffixes.storage
var fslogixSharePath = '\\\\${storageAccountName}.file.${storageEndpointSuffix}\\${fileShareName}'
var delValue = deleteLocalProfile ? '1' : '0'
var tempValue = preventTempProfile ? '1' : '0'
var failValue = preventLoginOnFailure ? '1' : '0'

// Build simple inline script - avoid multi-line strings for better command passing
var scriptCommands = [
  'New-Item C:\\Temp -ItemType Directory -Force | Out-Null'
  '[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12'
  'Invoke-WebRequest -Uri https://aka.ms/fslogix_download -OutFile C:\\Temp\\FSLogix.zip -UseBasicParsing'
  'Expand-Archive C:\\Temp\\FSLogix.zip C:\\Temp\\FSLogix -Force'
  'Start-Process C:\\Temp\\FSLogix\\x64\\Release\\FSLogixAppsSetup.exe -ArgumentList /install,/quiet,/norestart -Wait'
  'Start-Sleep 10'
  '$p=\'HKLM:\\SOFTWARE\\FSLogix\\Profiles\''
  'New-Item $p -Force | Out-Null'
  'Set-ItemProperty $p Enabled 1 -Type DWord'
  'Set-ItemProperty $p VHDLocations \'${fslogixSharePath}\' -Type MultiString'
  'Set-ItemProperty $p SizeInMBs ${profileSizeMB} -Type DWord'
  'Set-ItemProperty $p IsDynamic 1 -Type DWord'
  'Set-ItemProperty $p VolumeType VHDX -Type String'
  'Set-ItemProperty $p FlipFlopProfileDirectoryName 1 -Type DWord'
  'Set-ItemProperty $p DeleteLocalProfileWhenVHDShouldApply ${delValue} -Type DWord'
  'Set-ItemProperty $p PreventLoginWithTempProfile ${tempValue} -Type DWord'
  'Set-ItemProperty $p PreventLoginWithFailure ${failValue} -Type DWord'
  'Set-ItemProperty $p LockedRetryCount 3 -Type DWord'
  'Set-ItemProperty $p LockedRetryInterval 15 -Type DWord'
  'Set-ItemProperty $p ProfileType 0 -Type DWord'
  'Set-ItemProperty $p ReAttachIntervalSeconds 15 -Type DWord'
  'Set-ItemProperty $p ReAttachRetryCount 3 -Type DWord'
  'Set-ItemProperty $p AccessNetworkAsComputerObject 0 -Type DWord'
  'Set-ItemProperty HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters CloudKerberosTicketRetrievalEnabled 1 -Type DWord'
  '$k=\'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Domains\\file.core.windows.net\''
  'New-Item $k -Force | Out-Null'
  'Set-ItemProperty $k KdcProxy https://kerberos.microsoftonline.com/ -Type String'
  'Set-ItemProperty $k KdcProxyFlags 0x2 -Type DWord'
]

var officeCommands = enableOfficeContainer ? [
  '$o=\'HKLM:\\SOFTWARE\\Policies\\FSLogix\\ODFC\''
  'New-Item $o -Force | Out-Null'
  'Set-ItemProperty $o Enabled 1 -Type DWord'
  'Set-ItemProperty $o VHDLocations \'${fslogixSharePath}\' -Type MultiString'
  'Set-ItemProperty $o SizeInMBs 30720 -Type DWord'
  'Set-ItemProperty $o IsDynamic 1 -Type DWord'
  'Set-ItemProperty $o VolumeType VHDX -Type String'
  'Set-ItemProperty $o FlipFlopProfileDirectoryName 1 -Type DWord'
  'Set-ItemProperty $o IncludeOfficeActivation 1 -Type DWord'
  'Set-ItemProperty $o IncludeOneDrive 1 -Type DWord'
  'Set-ItemProperty $o IncludeOutlook 1 -Type DWord'
  'Set-ItemProperty $o IncludeTeams 1 -Type DWord'
] : []

var credCommands = useStorageKey ? [
  'cmdkey /add:${storageAccountName}.file.${storageEndpointSuffix} /user:Azure\\${storageAccountName} /pass:${storageAccountKey}'
] : []

var cleanupCommands = [
  'Remove-Item C:\\Temp\\FSLogix* -Recurse -Force -ErrorAction SilentlyContinue'
]

var allCommands = concat(scriptCommands, officeCommands, credCommands, cleanupCommands)
var finalScript = join(allCommands, '; ')

// ============================================================================
// Resources
// ============================================================================

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: '${vmName}/FSLogixConfig'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -Command "${finalScript}"'
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Extension provisioning state')
output provisioningState string = vmExtension.properties.provisioningState

@description('Configured VM name')
output configuredVmName string = vmName
