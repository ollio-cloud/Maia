// ============================================================================
// FSLogix VM Extension - Bicep Template
// Author: Maia Azure Solutions Architect
// Version: 1.0.0
// Description: Installs and configures FSLogix on AVD session hosts
// ============================================================================

@description('Array of VM names to configure FSLogix on')
param vmNames array = [
  'pauseisavd-0'
  'pauseisavd-1'
]

@description('Azure region')
param location string = 'australiasoutheast'

@description('Storage account name for FSLogix profiles')
param storageAccountName string = 'pauseisfslogix001'

@description('File share name for FSLogix profiles')
param fileShareName string = 'fslogix-profiles'

@description('Maximum profile size in MB')
param profileSizeMB int = 30720

@description('Storage account key for credential configuration (leave empty if using Azure AD Kerberos)')
@secure()
param storageAccountKey string = ''

@description('Use storage account key authentication instead of Azure AD Kerberos')
param useStorageAccountKey bool = false

@description('Enable separate Office 365 container for Outlook/Teams')
param enableOfficeContainer bool = true

@description('Delete local profile when FSLogix VHD applies')
param deleteLocalProfileWhenVHDApplies bool = true

@description('Prevent login if FSLogix cannot attach profile (creates temp profile)')
param preventLoginWithTempProfile bool = true

@description('Prevent login if FSLogix fails completely')
param preventLoginWithFailure bool = false

@description('Tags to apply to resources')
param tags object = {
  Environment: 'Production'
  Application: 'AVD'
  Component: 'FSLogix'
  ManagedBy: 'Bicep'
}

// ============================================================================
// Variables
// ============================================================================

var fslogixSharePath = '\\\\${storageAccountName}.file.core.windows.net\\${fileShareName}'

var profileContainerConfig = '''
$p="HKLM:\SOFTWARE\FSLogix\Profiles"
New-Item -Path $p -Force | Out-Null
Set-ItemProperty -Path $p -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $p -Name "VHDLocations" -Value "${SHARE_PATH}" -Type MultiString
Set-ItemProperty -Path $p -Name "SizeInMBs" -Value ${PROFILE_SIZE} -Type DWord
Set-ItemProperty -Path $p -Name "IsDynamic" -Value 1 -Type DWord
Set-ItemProperty -Path $p -Name "VolumeType" -Value "VHDX" -Type String
Set-ItemProperty -Path $p -Name "FlipFlopProfileDirectoryName" -Value 1 -Type DWord
Set-ItemProperty -Path $p -Name "DeleteLocalProfileWhenVHDShouldApply" -Value ${DELETE_LOCAL} -Type DWord
Set-ItemProperty -Path $p -Name "PreventLoginWithTempProfile" -Value ${PREVENT_TEMP} -Type DWord
Set-ItemProperty -Path $p -Name "PreventLoginWithFailure" -Value ${PREVENT_FAIL} -Type DWord
Set-ItemProperty -Path $p -Name "LockedRetryCount" -Value 3 -Type DWord
Set-ItemProperty -Path $p -Name "LockedRetryInterval" -Value 15 -Type DWord
Set-ItemProperty -Path $p -Name "ProfileType" -Value 0 -Type DWord
Set-ItemProperty -Path $p -Name "ReAttachIntervalSeconds" -Value 15 -Type DWord
Set-ItemProperty -Path $p -Name "ReAttachRetryCount" -Value 3 -Type DWord
Set-ItemProperty -Path $p -Name "AccessNetworkAsComputerObject" -Value 0 -Type DWord
Set-ItemProperty -Path $p -Name "RebootOnUserLogoff" -Value 0 -Type DWord
Set-ItemProperty -Path $p -Name "VHDNameMatch" -Value "*" -Type String
Set-ItemProperty -Path $p -Name "VHDNamePattern" -Value "Profile_%username%" -Type String
'''

var officeContainerConfig = '''
$o="HKLM:\SOFTWARE\Policies\FSLogix\ODFC"
New-Item -Path $o -Force | Out-Null
Set-ItemProperty -Path $o -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "VHDLocations" -Value "${SHARE_PATH}" -Type MultiString
Set-ItemProperty -Path $o -Name "SizeInMBs" -Value 30720 -Type DWord
Set-ItemProperty -Path $o -Name "IsDynamic" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "VolumeType" -Value "VHDX" -Type String
Set-ItemProperty -Path $o -Name "FlipFlopProfileDirectoryName" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeOfficeActivation" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeOneDrive" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeOutlook" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeTeams" -Value 1 -Type DWord
Set-ItemProperty -Path $o -Name "IncludeOutlookPersonalization" -Value 1 -Type DWord
'''

var credentialConfig = useStorageAccountKey ? '''
cmdkey /add:${STORAGE_ACCOUNT}.file.core.windows.net /user:Azure\${STORAGE_ACCOUNT} /pass:${STORAGE_KEY}
''' : ''

var installScript = '''
$ErrorActionPreference = "Stop"
$LogPath = "C:\Temp\FSLogix-Install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Tee-Object -FilePath $LogPath -Append
}

try {
    New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
    Write-Log "Starting FSLogix installation"

    # Download FSLogix
    Write-Log "Downloading FSLogix..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://aka.ms/fslogix_download" -OutFile "C:\Temp\FSLogix.zip" -UseBasicParsing

    # Extract
    Write-Log "Extracting FSLogix..."
    Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force

    # Install
    Write-Log "Installing FSLogix..."
    Start-Process -FilePath "C:\Temp\FSLogix\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait
    Start-Sleep -Seconds 10

    # Configure Profile Container
    Write-Log "Configuring FSLogix Profile Container..."
    ${PROFILE_CONFIG}

    # Configure Office Container
    ${OFFICE_CONFIG}

    # Configure Credentials
    ${CRED_CONFIG}

    # Verify services
    Write-Log "Verifying FSLogix services..."
    $services = Get-Service -Name "frxsvc", "frxccds" -ErrorAction SilentlyContinue
    foreach ($svc in $services) {
        Write-Log "Service: $($svc.Name) - Status: $($svc.Status)"
    }

    # Cleanup
    Remove-Item -Path "C:\Temp\FSLogix.zip" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Temp\FSLogix" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Log "FSLogix installation completed successfully!"
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}
'''

// Build the complete script with variable substitution
var profileConfigResolved = replace(replace(replace(replace(replace(
  profileContainerConfig,
  '${SHARE_PATH}', fslogixSharePath),
  '${PROFILE_SIZE}', string(profileSizeMB)),
  '${DELETE_LOCAL}', deleteLocalProfileWhenVHDApplies ? '1' : '0'),
  '${PREVENT_TEMP}', preventLoginWithTempProfile ? '1' : '0'),
  '${PREVENT_FAIL}', preventLoginWithFailure ? '1' : '0')

var officeConfigResolved = enableOfficeContainer ? replace(officeContainerConfig, '${SHARE_PATH}', fslogixSharePath) : ''

var credConfigResolved = useStorageAccountKey ? replace(replace(credentialConfig, '${STORAGE_ACCOUNT}', storageAccountName), '${STORAGE_KEY}', storageAccountKey) : ''

var completeScript = replace(replace(replace(
  installScript,
  '${PROFILE_CONFIG}', profileConfigResolved),
  '${OFFICE_CONFIG}', officeConfigResolved),
  '${CRED_CONFIG}', credConfigResolved)

// ============================================================================
// Resources
// ============================================================================

// VM Extensions for FSLogix Configuration
resource vmExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for vmName in vmNames: {
  name: '${vmName}/FSLogixConfig'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "${completeScript}"'
    }
    protectedSettings: {}
  }
}]

// ============================================================================
// Outputs
// ============================================================================

@description('List of configured VMs')
output configuredVMs array = vmNames

@description('FSLogix share path')
output fslogixSharePath string = '\\\\${storageAccountName}.file.core.windows.net\\${fileShareName}'

@description('Authentication method used')
output authenticationMethod string = useStorageAccountKey ? 'Storage Account Key' : 'Azure AD Kerberos'
