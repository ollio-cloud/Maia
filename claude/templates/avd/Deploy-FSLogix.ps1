<#
.SYNOPSIS
    Deploys FSLogix infrastructure for Azure Virtual Desktop using ARM templates.

.DESCRIPTION
    This script deploys:
    1. FSLogix Storage Account with Premium File Share
    2. Azure AD Kerberos authentication (optional)
    3. RBAC permissions for AVD users
    4. FSLogix configuration on AVD session hosts via Custom Script Extension

.PARAMETER ResourceGroupName
    The resource group name for deployment

.PARAMETER Location
    Azure region for deployment

.PARAMETER StorageAccountName
    Name of the storage account for FSLogix profiles

.PARAMETER VMNames
    Array of VM names to configure FSLogix on

.PARAMETER TenantId
    Azure AD Tenant ID (for Kerberos authentication)

.PARAMETER TenantName
    Azure AD Tenant name (e.g., contoso.onmicrosoft.com)

.PARAMETER AVDUsersGroupName
    Name of the Azure AD group containing AVD users

.PARAMETER AVDAdminsGroupName
    Name of the Azure AD group containing AVD admins

.PARAMETER UseStorageKey
    Use storage account key instead of Azure AD Kerberos

.PARAMETER SkipStorageDeployment
    Skip storage account deployment (if already exists)

.PARAMETER SkipVMConfiguration
    Skip VM FSLogix configuration

.EXAMPLE
    .\Deploy-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -VMNames @("pauseisavd-0", "pauseisavd-1")

.EXAMPLE
    .\Deploy-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -UseStorageKey -VMNames @("pauseisavd-0")

.NOTES
    Author: Maia Azure Solutions Architect
    Version: 1.0.0
    Date: 2025-12-17
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "p-ause-mb-rg-avd",

    [Parameter(Mandatory = $false)]
    [string]$Location = "australiasoutheast",

    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName = "pauseisfslogix001",

    [Parameter(Mandatory = $false)]
    [string]$FileShareName = "fslogix-profiles",

    [Parameter(Mandatory = $false)]
    [int]$FileShareQuotaGB = 256,

    [Parameter(Mandatory = $false)]
    [string[]]$VMNames = @("pauseisavd-0", "pauseisavd-1"),

    [Parameter(Mandatory = $false)]
    [string]$TenantId = "",

    [Parameter(Mandatory = $false)]
    [string]$TenantName = "",

    [Parameter(Mandatory = $false)]
    [string]$AVDUsersGroupName = "AVD-Users",

    [Parameter(Mandatory = $false)]
    [string]$AVDAdminsGroupName = "AVD-Admins",

    [Parameter(Mandatory = $false)]
    [switch]$UseStorageKey,

    [Parameter(Mandatory = $false)]
    [switch]$SkipStorageDeployment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipVMConfiguration,

    [Parameter(Mandatory = $false)]
    [string]$TemplateBasePath = $PSScriptRoot
)

#region Functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level ERROR
            return $false
        }
        Write-Log "Connected to Azure subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level INFO
        return $true
    }
    catch {
        Write-Log "Error checking Azure connection: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Get-AzureADGroupObjectId {
    param([string]$GroupName)

    try {
        $group = Get-AzADGroup -DisplayName $GroupName -ErrorAction SilentlyContinue
        if ($group) {
            return $group.Id
        }
        Write-Log "Group '$GroupName' not found in Azure AD" -Level WARNING
        return ""
    }
    catch {
        Write-Log "Error getting group '$GroupName': $($_.Exception.Message)" -Level WARNING
        return ""
    }
}
#endregion

#region Main Script
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  FSLogix Deployment Script for AVD" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check Azure connection
if (-not (Test-AzureConnection)) {
    Write-Log "Please connect to Azure using Connect-AzAccount" -Level ERROR
    exit 1
}

# Get Tenant ID if not provided
if ([string]::IsNullOrEmpty($TenantId)) {
    $TenantId = (Get-AzContext).Tenant.Id
    Write-Log "Using Tenant ID from current context: $TenantId" -Level INFO
}

# Get Tenant Name if not provided
if ([string]::IsNullOrEmpty($TenantName)) {
    $tenant = Get-AzTenant -TenantId $TenantId
    $TenantName = $tenant.DefaultDomain
    Write-Log "Using Tenant Name: $TenantName" -Level INFO
}

# Get Azure AD Group Object IDs
Write-Log "Looking up Azure AD groups..." -Level INFO
$avdUsersGroupObjectId = Get-AzureADGroupObjectId -GroupName $AVDUsersGroupName
$avdAdminsGroupObjectId = Get-AzureADGroupObjectId -GroupName $AVDAdminsGroupName

if ([string]::IsNullOrEmpty($avdUsersGroupObjectId)) {
    Write-Log "AVD Users group not found. RBAC will not be configured automatically." -Level WARNING
}

# Verify resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Log "Resource group '$ResourceGroupName' not found!" -Level ERROR
    exit 1
}
Write-Log "Resource group verified: $ResourceGroupName" -Level SUCCESS

#region Deploy Storage Account
if (-not $SkipStorageDeployment) {
    Write-Host ""
    Write-Log "========== PHASE 1: Storage Account Deployment ==========" -Level INFO

    $storageTemplatePath = Join-Path $TemplateBasePath "fslogix-storage.json"
    $storageParametersPath = Join-Path $TemplateBasePath "parameters\fslogix-storage.parameters.json"

    # Check if template exists
    if (-not (Test-Path $storageTemplatePath)) {
        Write-Log "Storage template not found at: $storageTemplatePath" -Level ERROR
        exit 1
    }

    # Build parameters
    $storageParams = @{
        storageAccountName     = $StorageAccountName
        location               = $Location
        fileShareName          = $FileShareName
        fileShareQuotaGB       = $FileShareQuotaGB
        storageAccountSku      = "Premium_LRS"
        enableAzureADKerberos  = (-not $UseStorageKey)
        azureADTenantId        = $TenantId
        azureADTenantName      = $TenantName
        avdUsersGroupObjectId  = $avdUsersGroupObjectId
        avdAdminsGroupObjectId = $avdAdminsGroupObjectId
        enableSoftDelete       = $true
        softDeleteRetentionDays = 7
    }

    Write-Log "Deploying storage account: $StorageAccountName" -Level INFO
    Write-Log "File share: $FileShareName ($FileShareQuotaGB GB)" -Level INFO
    Write-Log "Azure AD Kerberos: $(-not $UseStorageKey)" -Level INFO

    try {
        $storageDeployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -Name "fslogix-storage-$(Get-Date -Format 'yyyyMMddHHmmss')" `
            -TemplateFile $storageTemplatePath `
            -TemplateParameterObject $storageParams `
            -Verbose

        if ($storageDeployment.ProvisioningState -eq "Succeeded") {
            Write-Log "Storage account deployed successfully!" -Level SUCCESS
            Write-Log "File Share UNC: $($storageDeployment.Outputs.fileShareUNC.Value)" -Level SUCCESS

            # Store outputs for VM configuration
            $script:StorageAccountKey = $storageDeployment.Outputs.storageAccountKey.Value
            $script:FileShareUNC = $storageDeployment.Outputs.fileShareUNC.Value
        }
        else {
            Write-Log "Storage deployment failed: $($storageDeployment.ProvisioningState)" -Level ERROR
            exit 1
        }
    }
    catch {
        Write-Log "Storage deployment error: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
}
else {
    Write-Log "Skipping storage deployment (SkipStorageDeployment flag set)" -Level INFO

    # Get existing storage account key
    try {
        $existingStorage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        $script:StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
        $script:FileShareUNC = "\\$StorageAccountName.file.core.windows.net\$FileShareName"
        Write-Log "Using existing storage account: $StorageAccountName" -Level INFO
    }
    catch {
        Write-Log "Could not retrieve existing storage account: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
}
#endregion

#region Configure VMs with FSLogix
if (-not $SkipVMConfiguration) {
    Write-Host ""
    Write-Log "========== PHASE 2: VM FSLogix Configuration ==========" -Level INFO

    $vmTemplatePath = Join-Path $TemplateBasePath "fslogix-vm-extension.json"

    # Check if template exists
    if (-not (Test-Path $vmTemplatePath)) {
        Write-Log "VM extension template not found at: $vmTemplatePath" -Level ERROR
        exit 1
    }

    # Verify VMs exist
    Write-Log "Verifying VMs exist..." -Level INFO
    $validVMs = @()
    foreach ($vmName in $VMNames) {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction SilentlyContinue
        if ($vm) {
            Write-Log "  Found VM: $vmName" -Level SUCCESS
            $validVMs += $vmName
        }
        else {
            Write-Log "  VM not found: $vmName" -Level WARNING
        }
    }

    if ($validVMs.Count -eq 0) {
        Write-Log "No valid VMs found to configure!" -Level ERROR
        exit 1
    }

    # Build parameters
    $vmParams = @{
        vmNames                         = $validVMs
        location                        = $Location
        storageAccountName              = $StorageAccountName
        fileShareName                   = $FileShareName
        profileSizeMB                   = 30720
        useStorageAccountKey            = $UseStorageKey
        storageAccountKey               = if ($UseStorageKey) { $script:StorageAccountKey } else { "" }
        enableOfficeContainer           = $true
        deleteLocalProfileWhenVHDApplies = $true
        preventLoginWithTempProfile     = $true
        preventLoginWithFailure         = $false
    }

    Write-Log "Configuring FSLogix on $($validVMs.Count) VM(s)..." -Level INFO
    foreach ($vm in $validVMs) {
        Write-Log "  - $vm" -Level INFO
    }

    try {
        $vmDeployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -Name "fslogix-vm-config-$(Get-Date -Format 'yyyyMMddHHmmss')" `
            -TemplateFile $vmTemplatePath `
            -TemplateParameterObject $vmParams `
            -Verbose

        if ($vmDeployment.ProvisioningState -eq "Succeeded") {
            Write-Log "FSLogix configuration deployed to all VMs!" -Level SUCCESS
        }
        else {
            Write-Log "VM configuration failed: $($vmDeployment.ProvisioningState)" -Level ERROR
        }
    }
    catch {
        Write-Log "VM configuration error: $($_.Exception.Message)" -Level ERROR
        exit 1
    }

    # Restart VMs to apply configuration
    Write-Log "Restarting VMs to apply FSLogix configuration..." -Level INFO
    foreach ($vmName in $validVMs) {
        Write-Log "  Restarting $vmName..." -Level INFO
        Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -NoWait
    }
    Write-Log "VM restarts initiated (running in background)" -Level SUCCESS
}
else {
    Write-Log "Skipping VM configuration (SkipVMConfiguration flag set)" -Level INFO
}
#endregion

#region Summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "Resource Group:     $ResourceGroupName"
Write-Host "Storage Account:    $StorageAccountName"
Write-Host "File Share:         $FileShareName"
Write-Host "File Share UNC:     \\$StorageAccountName.file.core.windows.net\$FileShareName"
Write-Host "Authentication:     $(if ($UseStorageKey) { 'Storage Account Key' } else { 'Azure AD Kerberos' })"
Write-Host "Configured VMs:     $($VMNames -join ', ')"
Write-Host ""

Write-Host "NEXT STEPS" -ForegroundColor Yellow
Write-Host "==========" -ForegroundColor Yellow
Write-Host "1. Wait for VMs to restart (2-3 minutes)"
Write-Host "2. Test user login to verify FSLogix profile creation"
Write-Host "3. Check FSLogix logs at: C:\ProgramData\FSLogix\Logs\"
Write-Host "4. Verify VHDX files created at: \\$StorageAccountName.file.core.windows.net\$FileShareName"
Write-Host ""

if (-not $UseStorageKey) {
    Write-Host "AZURE AD KERBEROS NOTE" -ForegroundColor Yellow
    Write-Host "======================" -ForegroundColor Yellow
    Write-Host "Azure AD Kerberos is enabled. Users must be members of the '$AVDUsersGroupName' group"
    Write-Host "to access the FSLogix file share."
    Write-Host ""
}
#endregion
