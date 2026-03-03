<#
.SYNOPSIS
    Validates FSLogix deployment on AVD session hosts.

.DESCRIPTION
    This script validates:
    1. Storage account accessibility
    2. File share connectivity
    3. FSLogix installation on VMs
    4. FSLogix configuration
    5. Profile container creation

.PARAMETER ResourceGroupName
    The resource group containing the AVD resources

.PARAMETER StorageAccountName
    Name of the FSLogix storage account

.PARAMETER VMNames
    Array of VM names to validate

.EXAMPLE
    .\Validate-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -StorageAccountName "pauseisfslogix001"

.NOTES
    Author: Maia Azure Solutions Architect
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "p-ause-mb-rg-avd",

    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName = "pauseisfslogix001",

    [Parameter(Mandatory = $false)]
    [string]$FileShareName = "fslogix-profiles",

    [Parameter(Mandatory = $false)]
    [string[]]$VMNames = @("pauseisavd-0", "pauseisavd-1")
)

#region Functions
function Write-ValidationResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Details = ""
    )

    $icon = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { "Green" } else { "Red" }

    Write-Host "$icon $Test" -ForegroundColor $color
    if ($Details) {
        Write-Host "       $Details" -ForegroundColor Gray
    }
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        return $null -ne $context
    }
    catch {
        return $false
    }
}
#endregion

#region Main
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  FSLogix Deployment Validation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group:  $ResourceGroupName"
Write-Host "Storage Account: $StorageAccountName"
Write-Host "File Share:      $FileShareName"
Write-Host "VMs:             $($VMNames -join ', ')"
Write-Host ""

# Check Azure connection
if (-not (Test-AzureConnection)) {
    Write-Host "ERROR: Not connected to Azure. Run Connect-AzAccount first." -ForegroundColor Red
    exit 1
}

$totalTests = 0
$passedTests = 0

#region Storage Account Validation
Write-Host "--- Storage Account Validation ---" -ForegroundColor Yellow

# Test 1: Storage account exists
$totalTests++
try {
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
    Write-ValidationResult -Test "Storage account exists" -Passed $true -Details $storageAccount.PrimaryEndpoints.File
    $passedTests++
}
catch {
    Write-ValidationResult -Test "Storage account exists" -Passed $false -Details $_.Exception.Message
}

# Test 2: Storage account is FileStorage kind
$totalTests++
if ($storageAccount) {
    $isFileStorage = $storageAccount.Kind -eq "FileStorage"
    Write-ValidationResult -Test "Storage account is FileStorage" -Passed $isFileStorage -Details "Kind: $($storageAccount.Kind)"
    if ($isFileStorage) { $passedTests++ }
}

# Test 3: Premium SKU
$totalTests++
if ($storageAccount) {
    $isPremium = $storageAccount.Sku.Name -like "Premium*"
    Write-ValidationResult -Test "Storage account is Premium tier" -Passed $isPremium -Details "SKU: $($storageAccount.Sku.Name)"
    if ($isPremium) { $passedTests++ }
}

# Test 4: Azure AD Kerberos enabled
$totalTests++
if ($storageAccount) {
    $aadKerberosEnabled = $storageAccount.AzureFilesIdentityBasedAuthentication.DirectoryServiceOptions -eq "AADKERB"
    Write-ValidationResult -Test "Azure AD Kerberos enabled" -Passed $aadKerberosEnabled -Details "DirectoryServiceOptions: $($storageAccount.AzureFilesIdentityBasedAuthentication.DirectoryServiceOptions)"
    if ($aadKerberosEnabled) { $passedTests++ }
}

# Test 5: File share exists
$totalTests++
try {
    $ctx = $storageAccount.Context
    $share = Get-AzStorageShare -Name $FileShareName -Context $ctx -ErrorAction Stop
    Write-ValidationResult -Test "File share '$FileShareName' exists" -Passed $true -Details "Quota: $($share.Quota) GB"
    $passedTests++
}
catch {
    Write-ValidationResult -Test "File share '$FileShareName' exists" -Passed $false -Details $_.Exception.Message
}
#endregion

#region VM Validation
Write-Host ""
Write-Host "--- VM Validation ---" -ForegroundColor Yellow

foreach ($vmName in $VMNames) {
    Write-Host ""
    Write-Host "VM: $vmName" -ForegroundColor Cyan

    # Test: VM exists
    $totalTests++
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction SilentlyContinue
    if ($vm) {
        Write-ValidationResult -Test "VM exists" -Passed $true -Details "Size: $($vm.HardwareProfile.VmSize)"
        $passedTests++
    }
    else {
        Write-ValidationResult -Test "VM exists" -Passed $false -Details "VM not found"
        continue
    }

    # Test: VM is running
    $totalTests++
    $vmStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Status
    $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
    $isRunning = $powerState -eq "VM running"
    Write-ValidationResult -Test "VM is running" -Passed $isRunning -Details "Status: $powerState"
    if ($isRunning) { $passedTests++ }

    # Test: FSLogix extension installed
    $totalTests++
    $extension = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $vmName -Name "FSLogixConfig" -ErrorAction SilentlyContinue
    if ($extension) {
        $extensionSuccess = $extension.ProvisioningState -eq "Succeeded"
        Write-ValidationResult -Test "FSLogix extension installed" -Passed $extensionSuccess -Details "State: $($extension.ProvisioningState)"
        if ($extensionSuccess) { $passedTests++ }
    }
    else {
        Write-ValidationResult -Test "FSLogix extension installed" -Passed $false -Details "Extension not found"
    }

    # Test: FSLogix configuration via Run Command
    if ($isRunning) {
        $totalTests++
        $validationScript = @'
$results = @()

# Check FSLogix services
$services = Get-Service -Name "frxsvc", "frxccds" -ErrorAction SilentlyContinue
$servicesRunning = ($services | Where-Object { $_.Status -eq "Running" }).Count -eq 2
$results += "Services Running: $servicesRunning"

# Check FSLogix registry
$regPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
$enabled = (Get-ItemProperty -Path $regPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
$vhdLocations = (Get-ItemProperty -Path $regPath -Name "VHDLocations" -ErrorAction SilentlyContinue).VHDLocations
$results += "FSLogix Enabled: $($enabled -eq 1)"
$results += "VHD Locations: $vhdLocations"

# Check FSLogix Apps installed
$fslogixPath = "C:\Program Files\FSLogix\Apps\frx.exe"
$installed = Test-Path $fslogixPath
$results += "FSLogix Installed: $installed"

$results -join "|"
'@

        try {
            $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $vmName -CommandId "RunPowerShellScript" -ScriptString $validationScript -ErrorAction Stop
            $output = $result.Value[0].Message

            if ($output -match "FSLogix Enabled: True" -and $output -match "Services Running: True") {
                Write-ValidationResult -Test "FSLogix configured and running" -Passed $true -Details ($output -replace '\|', ' | ')
                $passedTests++
            }
            else {
                Write-ValidationResult -Test "FSLogix configured and running" -Passed $false -Details ($output -replace '\|', ' | ')
            }
        }
        catch {
            Write-ValidationResult -Test "FSLogix configured and running" -Passed $false -Details $_.Exception.Message
        }
    }
}
#endregion

#region Profile Validation
Write-Host ""
Write-Host "--- Profile Container Validation ---" -ForegroundColor Yellow

# Check for existing profile containers
$totalTests++
try {
    $ctx = $storageAccount.Context
    $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value

    # List files in share using Azure PowerShell
    $files = Get-AzStorageFile -ShareName $FileShareName -Context $ctx -ErrorAction Stop

    if ($files) {
        $profileCount = ($files | Where-Object { $_.GetType().Name -eq "AzureStorageFileDirectory" }).Count
        Write-ValidationResult -Test "Profile containers in share" -Passed ($profileCount -gt 0) -Details "Found $profileCount profile folder(s)"
        if ($profileCount -gt 0) { $passedTests++ }
    }
    else {
        Write-ValidationResult -Test "Profile containers in share" -Passed $false -Details "No profiles found (this is normal if no users have logged in yet)"
    }
}
catch {
    Write-ValidationResult -Test "Profile containers in share" -Passed $false -Details $_.Exception.Message
}
#endregion

#region Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Validation Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$percentage = [math]::Round(($passedTests / $totalTests) * 100, 1)
$summaryColor = if ($percentage -ge 80) { "Green" } elseif ($percentage -ge 60) { "Yellow" } else { "Red" }

Write-Host "Tests Passed: $passedTests / $totalTests ($percentage%)" -ForegroundColor $summaryColor
Write-Host ""

if ($percentage -lt 100) {
    Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
    Write-Host "- Check FSLogix logs at: C:\ProgramData\FSLogix\Logs\" -ForegroundColor Gray
    Write-Host "- Verify Azure AD group membership for RBAC" -ForegroundColor Gray
    Write-Host "- Test user login to create first profile" -ForegroundColor Gray
}
else {
    Write-Host "All validations passed! FSLogix is ready for use." -ForegroundColor Green
}

Write-Host ""
Write-Host "File Share UNC: \\$StorageAccountName.file.core.windows.net\$FileShareName" -ForegroundColor Cyan
Write-Host ""
#endregion
