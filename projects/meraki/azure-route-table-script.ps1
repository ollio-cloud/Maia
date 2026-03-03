# =============================================================================
# KD Bus Sites VPN Migration - Azure Route Table Script (PowerShell)
# CR-2026-002
# Generated: 2026-02-02
# =============================================================================
#
# This script adds routes for all 24 KD Bus sites (71 subnets) to both
# Azure route tables for FortiGate VPN connectivity.
#
# Usage:
#   .\azure-route-table-script.ps1 -Phase <phase>
#   .\azure-route-table-script.ps1 -Site <site-name>
#
# Examples:
#   .\azure-route-table-script.ps1                    # Show summary
#   .\azure-route-table-script.ps1 -Site "Brookvale"  # Add routes for single site
#   .\azure-route-table-script.ps1 -Site "Brookvale" -WhatIf  # Dry run single site
#   .\azure-route-table-script.ps1 -Phase pilot       # Run Phase 1 only
#   .\azure-route-table-script.ps1 -Phase batch1      # Run Phase 2 only
#   .\azure-route-table-script.ps1 -Phase batch2      # Run Phase 3 only
#   .\azure-route-table-script.ps1 -Phase list        # List current routes
#   .\azure-route-table-script.ps1 -Rollback -Site "Brookvale"  # Rollback site
#   .\azure-route-table-script.ps1 -Rollback -Phase batch1      # Rollback phase
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Appropriate permissions on route tables
#
# =============================================================================

param(
    [ValidateSet("all", "pilot", "batch1", "batch2", "list")]
    [string]$Phase = "all",

    [switch]$Rollback,

    [string]$Site,

    [switch]$WhatIf
)

# Configuration
$Config = @{
    EastRG = "KD-Prod-RG"
    EastRT = "KD-Prod-RouteTable"
    EastNextHop = "10.200.1.68"

    SeastRG = "KD-Prod-RG-asr"
    SeastRT = "KD-Mel-RouteTable"
    SeastNextHop = "10.201.1.68"
}

# Site definitions with all subnets
$Sites = @{
    # Phase 1 - Pilot (WA) - 1 site, 2 subnets
    "Malaga-Morley" = @{
        Phase = "pilot"
        State = "WA"
        Subnets = @("10.9.52.0/24", "10.91.52.0/24")
    }

    # Phase 2 - Batch 1 (NSW) - 7 sites, 34 subnets - 9/2/2026 7:30 PM AEST
    "Belmont-North" = @{
        Phase = "batch1"
        State = "NSW"
        Subnets = @("10.21.52.0/24", "10.2.52.0/24", "10.24.52.0/24")
    }
    "Brookvale" = @{
        Phase = "batch1"
        State = "NSW"
        Subnets = @("10.2.64.0/24", "10.21.64.0/24", "10.28.64.0/24", "10.25.64.0/24", "10.26.64.0/24", "10.30.64.0/24", "10.31.64.0/24")
    }
    "North-Sydney" = @{
        Phase = "batch1"
        State = "NSW"
        Subnets = @("10.2.68.0/24", "10.21.68.0/24", "10.28.68.0/24", "10.25.68.0/24", "10.26.68.0/24", "10.30.68.0/24", "10.31.68.0/24")
    }
    "Mona-Vale" = @{
        Phase = "batch1"
        State = "NSW"
        Subnets = @("10.2.66.0/24", "10.21.66.0/24", "10.28.66.0/24", "10.25.66.0/24", "10.26.66.0/24", "10.30.66.0/24", "10.31.66.0/24")
    }
    "Wickham" = @{
        Phase = "batch1"
        State = "NSW"
        Subnets = @("10.2.60.0/24", "10.26.60.0/24", "10.21.60.0/24")
    }
    "Queens-Wharf" = @{
        Phase = "batch1"
        State = "NSW"
        Subnets = @("10.21.54.0/24", "10.2.54.0/24")
    }
    "Hamilton" = @{
        Phase = "batch1"
        State = "NSW"
        Subnets = @("10.21.50.0/24", "10.24.50.0/24", "10.2.50.0/24", "10.27.50.0/24", "172.20.120.0/24")
    }

    # Phase 3 - Batch 2 (SA/WA/QLD) - 16 sites, 35 subnets - 10/2/2026 7:30 PM AEST
    "Goolwa" = @{
        Phase = "batch2"
        State = "SA"
        Subnets = @("10.81.72.0/24", "10.8.72.0/24")
    }
    "Murray-Bridge" = @{
        Phase = "batch2"
        State = "SA"
        Subnets = @("10.81.58.0/24", "10.8.58.0/24")
    }
    "Mt-Barker" = @{
        Phase = "batch2"
        State = "SA"
        Subnets = @("10.81.62.0/24", "10.8.62.0/24")
    }
    "Aldgate" = @{
        Phase = "batch2"
        State = "SA"
        Subnets = @("10.81.64.0/24", "10.8.64.0/24")
    }
    "Pooraka" = @{
        Phase = "batch2"
        State = "SA"
        Subnets = @("10.81.54.0/24", "10.8.54.0/24")
    }
    "Willaston" = @{
        Phase = "batch2"
        State = "SA"
        Subnets = @("10.81.68.0/24", "10.8.68.0/24")
    }
    "Nuriootpa" = @{
        Phase = "batch2"
        State = "SA"
        Subnets = @("10.81.60.0/24", "10.8.60.0/24")
    }
    "Welshpool" = @{
        Phase = "batch2"
        State = "WA"
        Subnets = @("10.91.64.0/24", "10.9.64.0/24", "10.95.64.0/24")
    }
    "Walliston-Kalamunda" = @{
        Phase = "batch2"
        State = "WA"
        Subnets = @("10.91.66.0/24", "10.9.66.0/24", "10.9.67.0/24")
    }
    "Bayswater" = @{
        Phase = "batch2"
        State = "WA"
        Subnets = @("10.91.58.0/24", "10.9.58.0/24")
    }
    "Forrestfield" = @{
        Phase = "batch2"
        State = "WA"
        Subnets = @("10.41.1.0/24", "10.91.41.0/24")
    }
    "Redcliffe" = @{
        Phase = "batch2"
        State = "WA"
        Subnets = @("10.9.68.0/24", "10.91.68.0/24")
    }
    "Geraldton" = @{
        Phase = "batch2"
        State = "WA"
        Subnets = @("10.91.70.0/24", "10.9.70.0/24")
    }
    "Henley-Brook" = @{
        Phase = "batch2"
        State = "WA"
        Subnets = @("10.91.54.0/24", "10.9.54.0/24")
    }
    "Clontarf" = @{
        Phase = "batch2"
        State = "QLD"
        Subnets = @("10.71.52.0/24", "10.7.52.0/24", "10.75.52.0/24")
    }
    "North-Lakes" = @{
        Phase = "batch2"
        State = "QLD"
        Subnets = @("10.71.56.0/24", "10.7.56.0/24")
    }
}

# Logging functions
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Add route to both route tables
function Add-Route {
    param(
        [string]$SiteName,
        [string]$RouteName,
        [string]$AddressPrefix
    )

    Write-Info "Adding route: $RouteName ($AddressPrefix) for $SiteName"

    if ($WhatIf) {
        Write-Host "  [WHATIF] Would add to $($Config.EastRT) and $($Config.SeastRT)" -ForegroundColor Magenta
        return
    }

    # Add to Azure East
    try {
        az network route-table route create `
            --resource-group $Config.EastRG `
            --route-table-name $Config.EastRT `
            --name $RouteName `
            --address-prefix $AddressPrefix `
            --next-hop-type VirtualAppliance `
            --next-hop-ip-address $Config.EastNextHop `
            --output none 2>$null
        Write-Success "  Added to $($Config.EastRT)"
    }
    catch {
        Write-Err "  Failed to add to $($Config.EastRT): $_"
    }

    # Add to Azure South East
    try {
        az network route-table route create `
            --resource-group $Config.SeastRG `
            --route-table-name $Config.SeastRT `
            --name $RouteName `
            --address-prefix $AddressPrefix `
            --next-hop-type VirtualAppliance `
            --next-hop-ip-address $Config.SeastNextHop `
            --output none 2>$null
        Write-Success "  Added to $($Config.SeastRT)"
    }
    catch {
        Write-Err "  Failed to add to $($Config.SeastRT): $_"
    }
}

# Delete route from both route tables
function Remove-Route {
    param([string]$RouteName)

    Write-Info "Deleting route: $RouteName"

    if ($WhatIf) {
        Write-Host "  [WHATIF] Would delete from both route tables" -ForegroundColor Magenta
        return
    }

    az network route-table route delete `
        --resource-group $Config.EastRG `
        --route-table-name $Config.EastRT `
        --name $RouteName `
        --output none 2>$null

    az network route-table route delete `
        --resource-group $Config.SeastRG `
        --route-table-name $Config.SeastRT `
        --name $RouteName `
        --output none 2>$null

    Write-Success "  Deleted from both route tables"
}

# Process a single site
function Process-Site {
    param(
        [string]$SiteName,
        [switch]$Remove
    )

    if (-not $Sites.ContainsKey($SiteName)) {
        Write-Err "Unknown site: $SiteName"
        Write-Host "Available sites: $($Sites.Keys -join ', ')"
        return
    }

    $SiteData = $Sites[$SiteName]
    Write-Host ""
    Write-Info "Site: $SiteName ($($SiteData.Subnets.Count) subnets)"

    $netIndex = 1
    foreach ($subnet in $SiteData.Subnets) {
        $routeName = "KD-$SiteName-Net$netIndex"

        if ($Remove) {
            Remove-Route -RouteName $routeName
        }
        else {
            Add-Route -SiteName $SiteName -RouteName $routeName -AddressPrefix $subnet
        }
        $netIndex++
    }
}

# Process a phase
function Process-Phase {
    param(
        [string]$PhaseName,
        [switch]$Remove
    )

    $phaseSites = $Sites.GetEnumerator() | Where-Object { $_.Value.Phase -eq $PhaseName }
    $totalSubnets = ($phaseSites | ForEach-Object { $_.Value.Subnets.Count } | Measure-Object -Sum).Sum

    $phaseTitle = switch ($PhaseName) {
        "pilot" { "PHASE 1 - PILOT: Malaga-Morley (WA) - 4/2/2026 7:30 PM AEST" }
        "batch1" { "PHASE 2 - BATCH 1: NSW Sites (7 sites) - 9/2/2026 7:30 PM AEST" }
        "batch2" { "PHASE 3 - BATCH 2: SA/WA/QLD Sites (16 sites) - 10/2/2026 7:30 PM AEST" }
    }

    $color = switch ($PhaseName) {
        "pilot" { "Green" }
        "batch1" { "Cyan" }
        "batch2" { "Yellow" }
    }

    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor $color
    Write-Host "$phaseTitle ($totalSubnets subnets)" -ForegroundColor $color
    Write-Host "=============================================================================" -ForegroundColor $color

    foreach ($site in $phaseSites) {
        Process-Site -SiteName $site.Key -Remove:$Remove
    }

    $action = if ($Remove) { "removed" } else { "added" }
    Write-Success "$PhaseName complete: $totalSubnets subnets $action"
}

# List current routes
function Show-Routes {
    Write-Host ""
    Write-Host "============================================================================="
    Write-Host "Current routes in $($Config.EastRT)"
    Write-Host "============================================================================="
    az network route-table route list `
        --resource-group $Config.EastRG `
        --route-table-name $Config.EastRT `
        --output table

    Write-Host ""
    Write-Host "============================================================================="
    Write-Host "Current routes in $($Config.SeastRT)"
    Write-Host "============================================================================="
    az network route-table route list `
        --resource-group $Config.SeastRG `
        --route-table-name $Config.SeastRT `
        --output table
}

# Show summary
function Show-Summary {
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host "KD BUS VPN MIGRATION - ROUTE TABLE SUMMARY" -ForegroundColor White
    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host ""

    $phases = @("pilot", "batch1", "batch2")
    foreach ($p in $phases) {
        $phaseSites = $Sites.GetEnumerator() | Where-Object { $_.Value.Phase -eq $p }
        $siteCount = @($phaseSites).Count
        $subnetCount = ($phaseSites | ForEach-Object { $_.Value.Subnets.Count } | Measure-Object -Sum).Sum

        $label = switch ($p) {
            "pilot" { "Phase 1 - Pilot (WA)       4/2/2026 7:30 PM" }
            "batch1" { "Phase 2 - Batch 1 (NSW)    9/2/2026 7:30 PM" }
            "batch2" { "Phase 3 - Batch 2 (SA/WA/QLD) 10/2/2026 7:30 PM" }
        }

        Write-Host "$label : $siteCount sites, $subnetCount subnets"
    }

    $totalSites = $Sites.Count
    $totalSubnets = ($Sites.Values | ForEach-Object { $_.Subnets.Count } | Measure-Object -Sum).Sum
    Write-Host ""
    Write-Host "TOTAL: $totalSites sites, $totalSubnets subnets, $($totalSubnets * 2) route entries" -ForegroundColor Green
}

# =============================================================================
# MAIN
# =============================================================================

if ($WhatIf) {
    Write-Host "[WHATIF MODE] No changes will be made" -ForegroundColor Magenta
    Write-Host ""
}

if ($Rollback) {
    if ($Site) {
        Write-Host "Rolling back site: $Site" -ForegroundColor Yellow
        Process-Site -SiteName $Site -Remove
    }
    elseif ($Phase -ne "all") {
        Write-Host "Rolling back phase: $Phase" -ForegroundColor Yellow
        Process-Phase -PhaseName $Phase -Remove
    }
    else {
        Write-Err "Please specify -Site or -Phase for rollback"
    }
    exit
}

# Single site mode
if ($Site) {
    Process-Site -SiteName $Site
    exit
}

switch ($Phase) {
    "pilot" {
        Process-Phase -PhaseName "pilot"
    }
    "batch1" {
        Process-Phase -PhaseName "batch1"
    }
    "batch2" {
        Process-Phase -PhaseName "batch2"
    }
    "list" {
        Show-Routes
    }
    "all" {
        Show-Summary
        Write-Host ""
        Write-Host "Available sites:" -ForegroundColor Cyan
        foreach ($p in @("pilot", "batch1", "batch2")) {
            $phaseSites = $Sites.GetEnumerator() | Where-Object { $_.Value.Phase -eq $p } | Sort-Object Key
            foreach ($s in $phaseSites) {
                Write-Host "  $($s.Key) ($($s.Value.State), $($s.Value.Subnets.Count) subnets)" -ForegroundColor White
            }
        }
        Write-Host ""
        Write-Host "Run with -Site `"SiteName`" to add routes for a single site" -ForegroundColor Yellow
    }
}