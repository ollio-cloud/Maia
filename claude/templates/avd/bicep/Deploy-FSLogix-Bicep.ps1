<#
.SYNOPSIS
    Deploys FSLogix infrastructure using Bicep templates.

.DESCRIPTION
    This script deploys FSLogix storage and VM configuration using Bicep.
    Supports both combined deployment and modular deployment options.

.PARAMETER ResourceGroupName
    The resource group name for deployment

.PARAMETER DeploymentMode
    'Complete' - Deploy storage + VM configuration together
    'StorageOnly' - Deploy only storage account
    'VMOnly' - Deploy only VM extensions (storage must exist)

.PARAMETER ParameterFile
    Path to .bicepparam file (optional, uses defaults if not specified)

.EXAMPLE
    .\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd"

.EXAMPLE
    .\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -DeploymentMode "StorageOnly"

.NOTES
    Author: Maia Azure Solutions Architect
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "p-ause-mb-rg-avd",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Complete", "StorageOnly", "VMOnly")]
    [string]$DeploymentMode = "Complete",

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "",

    [Parameter(Mandatory = $false)]
    [string]$Location = "australiasoutheast",

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$scriptPath = $PSScriptRoot

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message" -ForegroundColor $color
}

# Header
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  FSLogix Bicep Deployment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check Azure connection
$context = Get-AzContext
if (-not $context) {
    Write-Log "Not connected to Azure. Please run Connect-AzAccount" -Level ERROR
    exit 1
}
Write-Log "Connected to: $($context.Subscription.Name)" -Level INFO

# Verify resource group
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Log "Resource group '$ResourceGroupName' not found" -Level ERROR
    exit 1
}
Write-Log "Resource group verified: $ResourceGroupName" -Level SUCCESS

# Select template and parameters based on deployment mode
switch ($DeploymentMode) {
    "Complete" {
        $templateFile = Join-Path $scriptPath "fslogix-complete.bicep"
        $defaultParamFile = Join-Path $scriptPath "fslogix-complete.bicepparam"
    }
    "StorageOnly" {
        $templateFile = Join-Path $scriptPath "fslogix-storage.bicep"
        $defaultParamFile = Join-Path $scriptPath "fslogix-storage.bicepparam"
    }
    "VMOnly" {
        $templateFile = Join-Path $scriptPath "fslogix-vm-extension.bicep"
        $defaultParamFile = Join-Path $scriptPath "fslogix-vm-extension.bicepparam"
    }
}

# Use provided parameter file or default
$paramFile = if ($ParameterFile) { $ParameterFile } else { $defaultParamFile }

# Verify files exist
if (-not (Test-Path $templateFile)) {
    Write-Log "Template file not found: $templateFile" -Level ERROR
    exit 1
}
Write-Log "Template: $templateFile" -Level INFO

if (Test-Path $paramFile) {
    Write-Log "Parameters: $paramFile" -Level INFO
} else {
    Write-Log "Parameter file not found, using template defaults" -Level WARNING
    $paramFile = $null
}

# Deploy
$deploymentName = "fslogix-$DeploymentMode-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Log "Deployment name: $deploymentName" -Level INFO
Write-Host ""

if ($WhatIf) {
    Write-Log "Running What-If analysis..." -Level INFO

    $whatIfParams = @{
        ResourceGroupName = $ResourceGroupName
        TemplateFile = $templateFile
        Mode = "Incremental"
    }
    if ($paramFile) {
        $whatIfParams.TemplateParameterFile = $paramFile
    }

    $result = Get-AzResourceGroupDeploymentWhatIfResult @whatIfParams
    $result | Format-List
} else {
    Write-Log "Starting deployment..." -Level INFO

    $deployParams = @{
        ResourceGroupName = $ResourceGroupName
        Name = $deploymentName
        TemplateFile = $templateFile
        Verbose = $true
    }
    if ($paramFile) {
        $deployParams.TemplateParameterFile = $paramFile
    }

    try {
        $deployment = New-AzResourceGroupDeployment @deployParams

        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-Host ""
            Write-Log "Deployment SUCCEEDED!" -Level SUCCESS
            Write-Host ""
            Write-Host "=== OUTPUTS ===" -ForegroundColor Green

            foreach ($output in $deployment.Outputs.GetEnumerator()) {
                Write-Host "  $($output.Key): $($output.Value.Value)" -ForegroundColor White
            }

            Write-Host ""
            Write-Host "=== NEXT STEPS ===" -ForegroundColor Yellow
            Write-Host "  1. Wait 2-3 minutes for VMs to apply configuration"
            Write-Host "  2. Test user login to verify FSLogix profile creation"
            Write-Host "  3. Check logs at: C:\ProgramData\FSLogix\Logs\"
            Write-Host ""
        } else {
            Write-Log "Deployment failed: $($deployment.ProvisioningState)" -Level ERROR
            exit 1
        }
    }
    catch {
        Write-Log "Deployment error: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
}
