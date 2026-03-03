// ============================================================================
// FSLogix Complete Deployment - Bicep Template
// Author: Maia Azure Solutions Architect
// Version: 1.0.0
// Description: Complete FSLogix deployment - Storage + VM Configuration
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the storage account for FSLogix profiles')
param storageAccountName string = 'pauseisfslogix001'

@description('Azure region for deployment')
param location string = 'australiasoutheast'

@description('Name of the file share for FSLogix profiles')
param fileShareName string = 'fslogix-profiles'

@description('Quota for the file share in GB')
@minValue(100)
@maxValue(102400)
param fileShareQuotaGB int = 256

@description('Array of VM names to configure FSLogix on')
param vmNames array = [
  'pauseisavd-0'
  'pauseisavd-1'
]

@description('Maximum profile size in MB (30GB default)')
param profileSizeMB int = 30720

@description('Enable Azure AD Kerberos authentication')
param enableAzureADKerberos bool = true

@description('Azure AD Tenant ID')
param azureADTenantId string = ''

@description('Azure AD Tenant name (e.g., contoso.onmicrosoft.com)')
param azureADTenantName string = ''

@description('Object ID of AVD users group for RBAC')
param avdUsersGroupObjectId string = ''

@description('Object ID of AVD admins group for RBAC')
param avdAdminsGroupObjectId string = ''

@description('Enable Office 365 container (Outlook/Teams)')
param enableOfficeContainer bool = true

@description('Delete local profile when FSLogix VHD applies')
param deleteLocalProfileWhenVHDApplies bool = true

@description('Prevent login with temp profile')
param preventLoginWithTempProfile bool = true

@description('Prevent login if FSLogix fails')
param preventLoginWithFailure bool = false

@description('Tags for all resources')
param tags object = {
  Environment: 'Production'
  Application: 'AVD'
  Component: 'FSLogix'
  HostPool: 'pauseisavdpool01'
  ManagedBy: 'Bicep'
}

// ============================================================================
// Variables
// ============================================================================

var storageFileDataSMBShareContributorRoleId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
var storageFileDataSMBShareElevatedContributorRoleId = 'a7264617-510b-434b-a828-9731dc254ea7'
var fslogixSharePath = '\\\\${storageAccountName}.file.core.windows.net\\${fileShareName}'

// FSLogix installation and configuration script
var fslogixScript = '''
$ErrorActionPreference="Stop"
$LogPath="C:\Temp\FSLogix-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log{param([string]$M);$t=Get-Date -Format "yyyy-MM-dd HH:mm:ss";"$t - $M"|Tee-Object -FilePath $LogPath -Append}
try{
New-Item -Path "C:\Temp" -ItemType Directory -Force|Out-Null
Write-Log "Starting FSLogix installation"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://aka.ms/fslogix_download" -OutFile "C:\Temp\FSLogix.zip" -UseBasicParsing
Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force
Start-Process -FilePath "C:\Temp\FSLogix\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait
Start-Sleep -Seconds 10
Write-Log "Configuring FSLogix"
$p="HKLM:\SOFTWARE\FSLogix\Profiles"
New-Item -Path $p -Force|Out-Null
Set-ItemProperty -Path $p -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $p -Name "VHDLocations" -Value "${SHARE}" -Type MultiString
Set-ItemProperty -Path $p -Name "SizeInMBs" -Value ${SIZE} -Type DWord
Set-ItemProperty -Path $p -Name "IsDynamic" -Value 1 -Type DWord
Set-ItemProperty -Path $p -Name "VolumeType" -Value "VHDX" -Type String
Set-ItemProperty -Path $p -Name "FlipFlopProfileDirectoryName" -Value 1 -Type DWord
Set-ItemProperty -Path $p -Name "DeleteLocalProfileWhenVHDShouldApply" -Value ${DEL} -Type DWord
Set-ItemProperty -Path $p -Name "PreventLoginWithTempProfile" -Value ${TEMP} -Type DWord
Set-ItemProperty -Path $p -Name "PreventLoginWithFailure" -Value ${FAIL} -Type DWord
Set-ItemProperty -Path $p -Name "LockedRetryCount" -Value 3 -Type DWord
Set-ItemProperty -Path $p -Name "LockedRetryInterval" -Value 15 -Type DWord
Set-ItemProperty -Path $p -Name "ProfileType" -Value 0 -Type DWord
Set-ItemProperty -Path $p -Name "ReAttachIntervalSeconds" -Value 15 -Type DWord
Set-ItemProperty -Path $p -Name "ReAttachRetryCount" -Value 3 -Type DWord
Set-ItemProperty -Path $p -Name "AccessNetworkAsComputerObject" -Value 0 -Type DWord
${OFFICE}
Remove-Item -Path "C:\Temp\FSLogix.zip" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Temp\FSLogix" -Recurse -Force -ErrorAction SilentlyContinue
Write-Log "FSLogix installed and configured successfully"
}catch{Write-Log "ERROR: $($_.Exception.Message)";throw}
'''

var officeConfig = enableOfficeContainer ? '''
$o="HKLM:\SOFTWARE\Policies\FSLogix\ODFC"
New-Item -Path $o -Force|Out-Null
Set-ItemProperty -Path $o -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "VHDLocations" -Value "${SHARE}" -Type MultiString
Set-ItemProperty -Path $o -Name "SizeInMBs" -Value 30720 -Type DWord
Set-ItemProperty -Path $o -Name "IsDynamic" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "VolumeType" -Value "VHDX" -Type String
Set-ItemProperty -Path $o -Name "FlipFlopProfileDirectoryName" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeOfficeActivation" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeOneDrive" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeOutlook" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeTeams" -Value 1 -Type DWord
''' : ''

var scriptResolved = replace(replace(replace(replace(replace(replace(
  fslogixScript,
  '${SHARE}', fslogixSharePath),
  '${SIZE}', string(profileSizeMB)),
  '${DEL}', deleteLocalProfileWhenVHDApplies ? '1' : '0'),
  '${TEMP}', preventLoginWithTempProfile ? '1' : '0'),
  '${FAIL}', preventLoginWithFailure ? '1' : '0'),
  '${OFFICE}', replace(officeConfig, '${SHARE}', fslogixSharePath))

// ============================================================================
// Resources
// ============================================================================

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'FileStorage'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    largeFileSharesState: 'Enabled'
    azureFilesIdentityBasedAuthentication: enableAzureADKerberos ? {
      directoryServiceOptions: 'AADKERB'
      activeDirectoryProperties: {
        domainName: azureADTenantName
        domainGuid: azureADTenantId
      }
    } : null
  }
}

// File Services
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// File Share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileServices
  name: fileShareName
  properties: {
    shareQuota: fileShareQuotaGB
    enabledProtocols: 'SMB'
    accessTier: 'Premium'
  }
}

// RBAC - AVD Users
resource avdUsersRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(avdUsersGroupObjectId)) {
  name: guid(fileShare.id, avdUsersGroupObjectId, storageFileDataSMBShareContributorRoleId)
  scope: fileShare
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataSMBShareContributorRoleId)
    principalId: avdUsersGroupObjectId
    principalType: 'Group'
  }
}

// RBAC - AVD Admins
resource avdAdminsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(avdAdminsGroupObjectId)) {
  name: guid(fileShare.id, avdAdminsGroupObjectId, storageFileDataSMBShareElevatedContributorRoleId)
  scope: fileShare
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataSMBShareElevatedContributorRoleId)
    principalId: avdAdminsGroupObjectId
    principalType: 'Group'
  }
}

// VM Extensions - FSLogix Configuration
resource vmExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for vmName in vmNames: {
  name: '${vmName}/FSLogixConfig'
  location: location
  tags: tags
  dependsOn: [
    fileShare
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "${scriptResolved}"'
    }
  }
}]

// ============================================================================
// Outputs
// ============================================================================

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('File share UNC path')
output fileShareUNC string = '\\\\${storageAccount.name}.file.core.windows.net\\${fileShareName}'

@description('Storage account key for fallback authentication')
#disable-next-line outputs-should-not-contain-secrets
output storageAccountKey string = storageAccount.listKeys().keys[0].value

@description('Configured VMs')
output configuredVMs array = vmNames

@description('Authentication method')
output authenticationMethod string = enableAzureADKerberos ? 'Azure AD Kerberos' : 'Storage Account Key'

@description('Profile size configured (MB)')
output profileSizeMB int = profileSizeMB

@description('Office container enabled')
output officeContainerEnabled bool = enableOfficeContainer
