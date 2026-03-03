<#
.SYNOPSIS
    Tests FSLogix Bicep deployment using What-If analysis.

.DESCRIPTION
    Performs comprehensive What-If analysis on FSLogix deployment to preview:
    - Resources to be created
    - Resources to be modified
    - Resources to be deleted
    - Configuration changes

.PARAMETER ResourceGroupName
    Target resource group for deployment

.PARAMETER TemplateFile
    Bicep template to test (defaults to main.bicep)

.PARAMETER ParameterFile
    Parameter file to use (defaults to main.bicepparam)

.PARAMETER Detailed
    Show detailed change analysis

.EXAMPLE
    .\Test-FSLogixDeployment.ps1 -ResourceGroupName "p-ause-mb-rg-avd"

.EXAMPLE
    .\Test-FSLogixDeployment.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -Detailed

.NOTES
    Author: Maia Azure Solutions Architect
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "p-ause-mb-rg-avd",

    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "main.bicep",

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "main.bicepparam",

    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"
$scriptPath = $PSScriptRoot

# ============================================================================
# Functions
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info {
    param([string]$Text)
    Write-Host "[INFO] $Text" -ForegroundColor White
}

function Write-Success {
    param([string]$Text)
    Write-Host "[SUCCESS] $Text" -ForegroundColor Green
}

function Write-Warning2 {
    param([string]$Text)
    Write-Host "[WARNING] $Text" -ForegroundColor Yellow
}

function Write-Change {
    param(
        [string]$Action,
        [string]$Resource,
        [string]$Details = ""
    )

    $color = switch ($Action) {
        "Create" { "Green" }
        "Modify" { "Yellow" }
        "Delete" { "Red" }
        "NoChange" { "Gray" }
        default { "White" }
    }

    $icon = switch ($Action) {
        "Create" { "[+]" }
        "Modify" { "[~]" }
        "Delete" { "[-]" }
        "NoChange" { "[=]" }
        default { "[?]" }
    }

    Write-Host "  $icon $Action`: $Resource" -ForegroundColor $color
    if ($Details) {
        Write-Host "      $Details" -ForegroundColor Gray
    }
}

# ============================================================================
# Main Script
# ============================================================================

Write-Header "FSLogix Deployment What-If Analysis"

# Check Azure connection
Write-Info "Checking Azure connection..."
$context = Get-AzContext
if (-not $context) {
    Write-Host "ERROR: Not connected to Azure. Run Connect-AzAccount" -ForegroundColor Red
    exit 1
}
Write-Success "Connected to: $($context.Subscription.Name)"
Write-Info "Subscription ID: $($context.Subscription.Id)"
Write-Info "Tenant ID: $($context.Tenant.Id)"

# Verify resource group
Write-Host ""
Write-Info "Verifying resource group..."
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "ERROR: Resource group '$ResourceGroupName' not found" -ForegroundColor Red
    exit 1
}
Write-Success "Resource group found: $ResourceGroupName"
Write-Info "Location: $($rg.Location)"

# Verify template files
Write-Host ""
Write-Info "Verifying template files..."
$templatePath = Join-Path $scriptPath $TemplateFile
$paramPath = Join-Path $scriptPath $ParameterFile

if (-not (Test-Path $templatePath)) {
    Write-Host "ERROR: Template not found: $templatePath" -ForegroundColor Red
    exit 1
}
Write-Success "Template found: $TemplateFile"

if (Test-Path $paramPath) {
    Write-Success "Parameter file found: $ParameterFile"
} else {
    Write-Warning2 "Parameter file not found, using defaults"
    $paramPath = $null
}

# Run What-If analysis
Write-Header "Running What-If Analysis"

Write-Info "This may take 30-60 seconds..."
Write-Host ""

$whatIfParams = @{
    ResourceGroupName = $ResourceGroupName
    TemplateFile = $templatePath
    Mode = "Incremental"
}

if ($paramPath) {
    $whatIfParams.TemplateParameterFile = $paramPath
}

try {
    $result = Get-AzResourceGroupDeploymentWhatIfResult @whatIfParams

    # Summary
    Write-Header "What-If Summary"

    $changes = $result.Changes
    $createCount = ($changes | Where-Object { $_.ChangeType -eq 'Create' }).Count
    $modifyCount = ($changes | Where-Object { $_.ChangeType -eq 'Modify' }).Count
    $deleteCount = ($changes | Where-Object { $_.ChangeType -eq 'Delete' }).Count
    $noChangeCount = ($changes | Where-Object { $_.ChangeType -eq 'NoChange' }).Count

    Write-Host "Total Changes: $($changes.Count)" -ForegroundColor White
    Write-Host "  Resources to CREATE:  $createCount" -ForegroundColor Green
    Write-Host "  Resources to MODIFY:  $modifyCount" -ForegroundColor Yellow
    Write-Host "  Resources to DELETE:  $deleteCount" -ForegroundColor Red
    Write-Host "  Resources UNCHANGED:  $noChangeCount" -ForegroundColor Gray
    Write-Host ""

    # Detailed changes
    Write-Header "Resource Changes"

    # Group by change type
    $grouped = $changes | Group-Object ChangeType

    foreach ($group in $grouped) {
        $changeType = $group.Name
        Write-Host ""
        Write-Host "$changeType ($($group.Count)):" -ForegroundColor Cyan
        Write-Host ""

        foreach ($change in $group.Group) {
            $resourceType = $change.ResourceType
            $resourceName = $change.ResourceName

            if ($Detailed -and $change.Delta) {
                $details = "Properties: $($change.Delta.Count) changes"
                Write-Change -Action $changeType -Resource "$resourceType/$resourceName" -Details $details

                # Show property changes
                foreach ($delta in $change.Delta) {
                    Write-Host "        Property: $($delta.Path)" -ForegroundColor DarkGray
                    Write-Host "        Before: $($delta.Before)" -ForegroundColor DarkGray
                    Write-Host "        After:  $($delta.After)" -ForegroundColor DarkGray
                    Write-Host ""
                }
            } else {
                Write-Change -Action $changeType -Resource "$resourceType/$resourceName"
            }
        }
    }

    # Cost estimate note
    Write-Host ""
    Write-Host "=== COST ESTIMATE ===" -ForegroundColor Yellow
    Write-Host "What-If does not show cost estimates." -ForegroundColor Gray
    Write-Host "For cost analysis, use Azure Pricing Calculator:" -ForegroundColor Gray
    Write-Host "https://azure.microsoft.com/pricing/calculator/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Estimated FSLogix costs:" -ForegroundColor Gray
    Write-Host "  - Storage Account (Premium_LRS): ~$0.16/GB/month" -ForegroundColor Gray
    Write-Host "  - File Share (256GB): ~$41/month" -ForegroundColor Gray
    Write-Host ""

    # Next steps
    Write-Header "Next Steps"

    if ($createCount -gt 0 -or $modifyCount -gt 0) {
        Write-Host "To deploy these changes:" -ForegroundColor White
        Write-Host ""
        Write-Host "# Option 1: PowerShell Script" -ForegroundColor Cyan
        Write-Host "  .\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "# Option 2: Direct deployment" -ForegroundColor Cyan
        Write-Host "  New-AzResourceGroupDeployment \`" -ForegroundColor Gray
        Write-Host "      -ResourceGroupName '$ResourceGroupName' \`" -ForegroundColor Gray
        Write-Host "      -TemplateFile '$TemplateFile' \`" -ForegroundColor Gray
        if ($paramPath) {
            Write-Host "      -TemplateParameterFile '$ParameterFile'" -ForegroundColor Gray
        }
        Write-Host ""
    } else {
        Write-Success "No changes detected. Environment matches template."
    }

    # Warnings
    if ($deleteCount -gt 0) {
        Write-Host ""
        Write-Host "WARNING: $deleteCount resource(s) will be DELETED!" -ForegroundColor Red
        Write-Host "Review the changes carefully before deploying." -ForegroundColor Red
    }

} catch {
    Write-Host ""
    Write-Host "ERROR: What-If analysis failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Common causes:" -ForegroundColor Yellow
    Write-Host "  - Missing parameters in parameter file" -ForegroundColor Gray
    Write-Host "  - Invalid resource names or SKUs" -ForegroundColor Gray
    Write-Host "  - Insufficient permissions" -ForegroundColor Gray
    Write-Host "  - Template syntax errors" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Success "What-If analysis completed successfully"
Write-Host ""
