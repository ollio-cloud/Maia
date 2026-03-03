# =============================================================================
# KD Bus / KAB - Azure Public IP Migration Script (SonicWall → FortiGate)
# CR-4404660
# Generated: 2026-02-12
# =============================================================================
#
# This script migrates public IPs from SonicWall NIC(s) to FortiGate NIC
# by dissociating from the source NIC and associating to the target NIC.
#
# Usage:
#   .\azure-pip-migration-script.ps1                          # Show summary + current state
#   .\azure-pip-migration-script.ps1 -Discover                # Show current NIC associations
#   .\azure-pip-migration-script.ps1 -Migrate -Name "KD-QLD-TIMS-PublicIP" -WhatIf   # Dry run single IP
#   .\azure-pip-migration-script.ps1 -Migrate -Name "KD-QLD-TIMS-PublicIP"           # Migrate single IP
#   .\azure-pip-migration-script.ps1 -Migrate -Group "KD-TIMS"  -WhatIf              # Dry run group
#   .\azure-pip-migration-script.ps1 -Migrate -Group "KD-TIMS"                       # Migrate group
#   .\azure-pip-migration-script.ps1 -Migrate -All -WhatIf                           # Dry run all
#   .\azure-pip-migration-script.ps1 -Rollback -Name "KD-QLD-TIMS-PublicIP"          # Rollback single IP
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Appropriate permissions on NICs and Public IPs
#   - FortiGate NIC must be in the same region as the public IPs
#
# IMPORTANT: Update $TargetNicName and $SourceNicName before running!
#
# =============================================================================

param(
    [switch]$Migrate,
    [switch]$Rollback,
    [switch]$Discover,
    [switch]$All,
    [string]$Name,
    [string]$Group,
    [switch]$WhatIf
)

# =============================================================================
# CONFIGURATION - UPDATE THESE BEFORE RUNNING
# =============================================================================
$ResourceGroup = "KD-Prod-RG"
$TargetNicName = "ATE-AE-fgt-nic1"         # FortiGate East external NIC (10.200.1.4)
$SourceNicName = "ATEUTM05-interface-X1"    # SonicWall WAN NIC (10.200.254.4) - for rollback
$SubnetId      = ""                         # <-- UPDATE: Subnet ID (auto-discovered if empty)

# =============================================================================
# PRIMARY OUTBOUND IP DEFINITIONS (Phase 1A/2A - migrate FIRST)
# =============================================================================
# These are the outbound NAT IPs whitelisted by external services.
# They replace the existing FortiGate primary public IPs.
# Migration: Manual az CLI commands (not handled by this script's -Migrate flag)
#
# East:  52.237.241.132 (KD-UTM-PublicIP) -> ATE-AE-fgt-nic1 primary (replaces 68.218.113.249 / ATE-AE-FGT-PIP2)
#   Dissociate: az network nic ip-config update --resource-group KD-Prod-RG --nic-name ATEUTM05-interface-X1 --name ipconfig1 --remove publicIpAddress
#   Swap:       az network nic ip-config update --resource-group KD-Prod-RG --nic-name ATE-AE-fgt-nic1 --name ipconfig1 --public-ip-address KD-UTM-PublicIP
#
# SE:    23.101.226.122 (Sophos-PublicIP) -> ATE-ASE-fgt-nic1 primary (replaces 4.200.139.87 / ATE-ASE-fgt-pip2)
#   Dissociate: az network nic ip-config update --resource-group KD-Mel-Temp --nic-name ATEUTM04-interface-X1 --name ipconfig1 --remove publicIpAddress
#   Swap:       az network nic ip-config update --resource-group KD-Prod-RG-asr --nic-name ATE-ASE-fgt-nic1 --name ipconfig1 --public-ip-address Sophos-PublicIP
#
# Rollback (swap back to original FortiGate PIPs):
#   East: az network nic ip-config update --resource-group KD-Prod-RG --nic-name ATE-AE-fgt-nic1 --name ipconfig1 --public-ip-address ATE-AE-FGT-PIP2
#   SE:   az network nic ip-config update --resource-group KD-Prod-RG-asr --nic-name ATE-ASE-fgt-nic1 --name ipconfig1 --public-ip-address ATE-ASE-fgt-pip2
#
# Default route (0.0.0.0/0) must also be updated after primary IP swap:
#   East: az network route-table route update --resource-group KD-Prod-RG --route-table-name KD-Prod-RouteTable --name KD-Default-Route --next-hop-type VirtualAppliance --next-hop-ip-address 10.200.1.68
#   SE:   az network route-table route update --resource-group KD-Prod-RG-asr --route-table-name KD-Mel-RouteTable --name Mel-Default-Route --next-hop-type VirtualAppliance --next-hop-ip-address 10.201.1.68

# =============================================================================
# SERVICE PUBLIC IP DEFINITIONS (Phase 3-8 - migrate AFTER primary IP + default route)
# =============================================================================
$PublicIPs = @(
    # KD TIMS Production
    @{ Name = "KD-QLD-TIMS-PublicIP";     PrivateIP = "10.200.1.6";  PublicIP = "52.187.240.188";  MappedIP = "10.200.10.88";  Group = "KD-TIMS";      Env = "Prod" }
    @{ Name = "KD-SA-TIMS-PublicIP";      PrivateIP = "10.200.1.7";  PublicIP = "52.187.246.55";   MappedIP = "10.200.10.125"; Group = "KD-TIMS";      Env = "Prod" }
    @{ Name = "KD-WA-TIMS-PublicIP";      PrivateIP = "10.200.1.8";  PublicIP = "52.187.244.82";   MappedIP = "10.200.10.153"; Group = "KD-TIMS";      Env = "Prod" }
    @{ Name = "KD-NSW-TIMS-PublicIP";     PrivateIP = "10.200.1.9";  PublicIP = "13.75.135.21";    MappedIP = "10.200.10.56";  Group = "KD-TIMS";      Env = "Prod" }

    # KD Other
    # TODO: KD-ATESMA01-PublicIP (40.126.228.221) - NOT FOUND in az network public-ip list. Verify actual PIP name/RG!
    @{ Name = "KD-ATESMA01-PublicIP";     PrivateIP = "10.200.1.12"; PublicIP = "40.126.228.221";  MappedIP = "10.200.10.7";   Group = "KD-Other";     Env = "Prod" }
    @{ Name = "KD-ConnX-PublicIP";        PrivateIP = "10.200.1.13"; PublicIP = "13.75.229.11";    MappedIP = "";              Group = "KD-Other";     Env = "Prod" }
    @{ Name = "KD-KDBMEX01-PublicIP";     PrivateIP = "10.200.1.14"; PublicIP = "52.156.166.57";   MappedIP = "10.200.10.54";  Group = "KD-Other";     Env = "Prod" }

    # KAB Austrics Production
    @{ Name = "KAB-Az-Austrics-WA-pip";   PrivateIP = "10.200.1.5";  PublicIP = "13.75.136.76";    MappedIP = "10.200.10.6";   Group = "KAB-Austrics"; Env = "Prod" }
    @{ Name = "KAB-Az-Austrics-NSW-pip";  PrivateIP = "10.200.1.10"; PublicIP = "52.156.182.48";   MappedIP = "10.200.10.9";   Group = "KAB-Austrics"; Env = "Prod" }
    @{ Name = "KAB-Az-Austrics-SA-pip";   PrivateIP = "10.200.1.15"; PublicIP = "20.191.198.18";   MappedIP = "10.200.10.11";  Group = "KAB-Austrics"; Env = "Prod" }

    # KAB TIMS Production
    @{ Name = "KAB-AZ-TIMS-NSW-pip";     PrivateIP = "10.200.1.11"; PublicIP = "52.237.233.233";  MappedIP = "10.200.10.10";  Group = "KAB-TIMS";     Env = "Prod" }
    @{ Name = "KAB-AZ-TIMS-QLD-pip";     PrivateIP = "10.200.1.16"; PublicIP = "40.126.224.167";  MappedIP = "10.200.10.12";  Group = "KAB-TIMS";     Env = "Prod" }
    @{ Name = "KAB-AZ-TIMS-SA-pip";      PrivateIP = "10.200.1.17"; PublicIP = "20.188.250.100";  MappedIP = "10.200.10.13";  Group = "KAB-TIMS";     Env = "Prod" }
    @{ Name = "KAB-AZ-TIMS-WA-pip";      PrivateIP = "10.200.1.18"; PublicIP = "20.188.255.96";   MappedIP = "10.200.10.14";  Group = "KAB-TIMS";     Env = "Prod" }

    # KAB TIMS UAT
    @{ Name = "KAB-AZ-TIMS-NSW-UAT-pip"; PrivateIP = "10.200.1.19"; PublicIP = "20.188.255.62";   MappedIP = "10.200.10.15";  Group = "KAB-TIMS-UAT"; Env = "UAT"  }
    @{ Name = "KAB-AZ-TIMS-QLD-UAT-pip"; PrivateIP = "10.200.1.20"; PublicIP = "20.191.207.10";   MappedIP = "10.200.10.16";  Group = "KAB-TIMS-UAT"; Env = "UAT"  }
    @{ Name = "KAB-AZ-TIMS-WA-UAT-pip";  PrivateIP = "10.200.1.21"; PublicIP = "20.191.201.167";  MappedIP = "10.200.10.18";  Group = "KAB-TIMS-UAT"; Env = "UAT"  }
    @{ Name = "KAB-AZ-TIMS-SA-UAT-pip2"; PrivateIP = "10.200.1.22"; PublicIP = "52.156.180.207";  MappedIP = "10.200.10.19";  Group = "KAB-TIMS-UAT"; Env = "UAT"  }

    # KAB RDG (NOTE: This PIP is in resource group KD-Prod-RemoteUsers-RDS, not KD-Prod-RG)
    @{ Name = "KAB-AZ-RDG-pip";          PrivateIP = "10.200.1.23"; PublicIP = "4.254.88.95";     MappedIP = "10.200.10.20";  Group = "KAB-RDG";      Env = "Prod"; RG = "KD-Prod-RemoteUsers-RDS" }
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
function Write-Info    { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn    { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err     { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Get-PipAssociation {
    param([string]$PipName, [string]$PipRG = $ResourceGroup)
    $pip = az network public-ip show --resource-group $PipRG --name $PipName --query "{ip:ipAddress, configId:ipConfiguration.id}" --output json 2>$null | ConvertFrom-Json
    return $pip
}

function Get-NicAndConfigFromId {
    param([string]$ConfigId)
    if ($ConfigId -match "/networkInterfaces/([^/]+)/ipConfigurations/([^/]+)") {
        return @{ NicName = $Matches[1]; ConfigName = $Matches[2] }
    }
    return $null
}

# =============================================================================
# DISCOVER - Show current associations
# =============================================================================
function Show-Discovery {
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host "PUBLIC IP CURRENT ASSOCIATIONS" -ForegroundColor White
    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host ""

    foreach ($pip in $PublicIPs) {
        $pipRG = if ($pip.RG) { $pip.RG } else { $ResourceGroup }
        $assoc = Get-PipAssociation -PipName $pip.Name -PipRG $pipRG
        if ($assoc.configId) {
            $nicInfo = Get-NicAndConfigFromId -ConfigId $assoc.configId
            Write-Host "$($pip.Name)" -ForegroundColor Cyan -NoNewline
            Write-Host " ($($pip.PublicIP))" -ForegroundColor Gray
            Write-Host "  NIC: $($nicInfo.NicName) | Config: $($nicInfo.ConfigName) | Private: $($pip.PrivateIP)" -ForegroundColor White
        }
        else {
            Write-Host "$($pip.Name)" -ForegroundColor Yellow -NoNewline
            Write-Host " ($($pip.PublicIP)) - NOT ASSOCIATED" -ForegroundColor Yellow
        }
    }
}

# =============================================================================
# MIGRATE - Move public IP from source NIC to target NIC
# =============================================================================
function Move-PublicIP {
    param(
        [hashtable]$PipEntry,
        [switch]$Remove  # For rollback
    )

    $pipName = $PipEntry.Name
    $privateIp = $PipEntry.PrivateIP
    $pipRG = if ($PipEntry.RG) { $PipEntry.RG } else { $ResourceGroup }
    $configName = $pipName -replace '[^a-zA-Z0-9-]', ''  # Clean name for IP config

    Write-Host ""
    Write-Info "Processing: $pipName ($($PipEntry.PublicIP)) -> Private: $privateIp"
    if ($pipRG -ne $ResourceGroup) { Write-Info "  (PIP resource group: $pipRG)" }

    # Step 1: Get current association
    $assoc = Get-PipAssociation -PipName $pipName -PipRG $pipRG
    if (-not $assoc) {
        Write-Err "Could not find public IP: $pipName"
        return $false
    }

    $targetNic = if ($Remove) { $SourceNicName } else { $TargetNicName }
    $currentNicInfo = $null

    if ($assoc.configId) {
        $currentNicInfo = Get-NicAndConfigFromId -ConfigId $assoc.configId
        Write-Info "  Currently on: $($currentNicInfo.NicName) / $($currentNicInfo.ConfigName)"

        # Check if already on target
        if ($currentNicInfo.NicName -eq $targetNic) {
            Write-Warn "  Already on target NIC ($targetNic) - skipping"
            return $true
        }
    }
    else {
        Write-Info "  Currently: NOT ASSOCIATED"
    }

    if ($WhatIf) {
        if ($currentNicInfo) {
            Write-Host "  [WHATIF] Would dissociate from $($currentNicInfo.NicName) / $($currentNicInfo.ConfigName)" -ForegroundColor Magenta
        }
        Write-Host "  [WHATIF] Would create IP config on $targetNic with private IP $privateIp" -ForegroundColor Magenta
        Write-Host "  [WHATIF] Would associate $pipName to $targetNic" -ForegroundColor Magenta
        return $true
    }

    # Step 2: Dissociate from current NIC (if associated)
    if ($currentNicInfo) {
        Write-Info "  Dissociating from $($currentNicInfo.NicName)..."
        try {
            az network nic ip-config update `
                --resource-group $ResourceGroup `
                --nic-name $currentNicInfo.NicName `
                --name $currentNicInfo.ConfigName `
                --remove publicIpAddress `
                --output none 2>$null

            if ($LASTEXITCODE -ne 0) { throw "az command failed" }
            Write-Success "  Dissociated from $($currentNicInfo.NicName)"
        }
        catch {
            Write-Err "  Failed to dissociate: $_"
            return $false
        }

        # Brief pause to let Azure propagate
        Start-Sleep -Seconds 2
    }

    # Step 3: Create secondary IP config on target NIC with public IP
    # If PIP is in a different RG, we need to use its full resource ID
    $pipRef = if ($pipRG -ne $ResourceGroup) {
        $subId = (az account show --query "id" -o tsv 2>$null)
        "/subscriptions/$subId/resourceGroups/$pipRG/providers/Microsoft.Network/publicIPAddresses/$pipName"
    } else { $pipName }
    Write-Info "  Creating IP config on $targetNic (private: $privateIp)..."
    try {
        az network nic ip-config create `
            --resource-group $ResourceGroup `
            --nic-name $targetNic `
            --name $configName `
            --private-ip-address $privateIp `
            --public-ip-address $pipRef `
            --output none 2>$null

        if ($LASTEXITCODE -ne 0) { throw "az command failed" }
        Write-Success "  Associated $pipName to $targetNic ($privateIp)"
    }
    catch {
        Write-Err "  Failed to associate to $targetNic : $_"
        Write-Err "  PUBLIC IP $pipName MAY BE UNASSOCIATED - manual intervention needed!"
        return $false
    }

    return $true
}

# =============================================================================
# SUMMARY
# =============================================================================
function Show-Summary {
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host "PUBLIC IP MIGRATION SUMMARY - SonicWall to FortiGate" -ForegroundColor White
    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host ""
    Write-Host "Resource Group:  $ResourceGroup" -ForegroundColor Gray
    Write-Host "Source NIC:      $SourceNicName" -ForegroundColor Gray
    Write-Host "Target NIC:      $TargetNicName" -ForegroundColor Gray
    Write-Host ""

    $groups = $PublicIPs | Group-Object { $_.Group }
    foreach ($g in $groups | Sort-Object Name) {
        $prodCount = @($g.Group | Where-Object { $_.Env -eq "Prod" }).Count
        $uatCount = @($g.Group | Where-Object { $_.Env -eq "UAT" }).Count
        $envLabel = if ($uatCount -gt 0) { "($uatCount UAT)" } else { "(Prod)" }
        Write-Host "  $($g.Name): $($g.Count) IPs $envLabel" -ForegroundColor Cyan
        foreach ($pip in $g.Group) {
            $mapped = if ($pip.MappedIP) { " -> $($pip.MappedIP)" } else { "" }
            Write-Host "    $($pip.Name) -> $($pip.PrivateIP)$mapped ($($pip.PublicIP))" -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "TOTAL: $($PublicIPs.Count) public IPs to migrate" -ForegroundColor Green
    Write-Host ""
    Write-Host "Available groups: $( ($groups | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host '  .\azure-pip-migration-script.ps1 -Discover                                  # Check current state' -ForegroundColor White
    Write-Host '  .\azure-pip-migration-script.ps1 -Migrate -Name "KD-QLD-TIMS-PublicIP" -WhatIf  # Dry run one IP' -ForegroundColor White
    Write-Host '  .\azure-pip-migration-script.ps1 -Migrate -Name "KD-QLD-TIMS-PublicIP"          # Migrate one IP' -ForegroundColor White
    Write-Host '  .\azure-pip-migration-script.ps1 -Migrate -Group "KD-TIMS" -WhatIf              # Dry run group' -ForegroundColor White
    Write-Host '  .\azure-pip-migration-script.ps1 -Migrate -Group "KD-TIMS"                      # Migrate group' -ForegroundColor White
    Write-Host '  .\azure-pip-migration-script.ps1 -Migrate -All -WhatIf                          # Dry run all' -ForegroundColor White
}

# =============================================================================
# MAIN
# =============================================================================
if ($WhatIf -and ($Migrate -or $Rollback)) {
    Write-Host "[WHATIF MODE] No changes will be made" -ForegroundColor Magenta
    Write-Host ""
}

# Validate NIC names are configured
if (($Migrate -or $Rollback) -and -not $WhatIf) {
    if ($TargetNicName -eq "FORTIGATE-EAST-NIC") {
        Write-Err 'You must update $TargetNicName in the script before running migrations!'
        Write-Err 'Run: az network nic list --resource-group KD-Prod-RG --query "[].name" --output table'
        exit 1
    }
}

if ($Discover) {
    Show-Discovery
    exit
}

if ($Migrate -or $Rollback) {
    $action = if ($Rollback) { "ROLLBACK" } else { "MIGRATION" }
    $targets = @()

    if ($Name) {
        $targets = $PublicIPs | Where-Object { $_.Name -eq $Name }
        if (-not $targets) {
            Write-Err "Unknown public IP: $Name"
            Write-Host "Available IPs:" -ForegroundColor Yellow
            $PublicIPs | ForEach-Object { Write-Host "  $($_.Name)" }
            exit 1
        }
    }
    elseif ($Group) {
        $targets = $PublicIPs | Where-Object { $_.Group -eq $Group }
        if (-not $targets) {
            Write-Err "Unknown group: $Group"
            Write-Host "Available groups: $( ($PublicIPs | Group-Object { $_.Group } | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor Yellow
            exit 1
        }
    }
    elseif ($All) {
        $targets = $PublicIPs
    }
    else {
        Write-Err "Please specify -Name, -Group, or -All"
        exit 1
    }

    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host "$action : $($targets.Count) public IP(s)" -ForegroundColor White
    Write-Host "=============================================================================" -ForegroundColor White

    $success = 0
    $failed = 0

    foreach ($pip in $targets) {
        $result = Move-PublicIP -PipEntry $pip -Remove:$Rollback
        if ($result) { $success++ } else { $failed++ }
    }

    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor White
    Write-Host "$action COMPLETE: $success succeeded, $failed failed" -ForegroundColor $(if ($failed -gt 0) { "Yellow" } else { "Green" })
    Write-Host "=============================================================================" -ForegroundColor White
    exit
}

# Default: show summary
Show-Summary