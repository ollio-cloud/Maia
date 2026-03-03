<#
.SYNOPSIS
    Export Active Directory group members to CSV file.

.DESCRIPTION
    Retrieves all members of a specified AD group and exports user details to CSV.

.PARAMETER GroupName
    The name of the AD group to export members from.

.PARAMETER OutputPath
    Path for the output CSV file. Defaults to current directory with group name.

.PARAMETER IncludeNested
    Include members from nested groups (recursive).

.EXAMPLE
    .\Export-ADGroupMembers.ps1 -GroupName "IT-Staff"

.EXAMPLE
    .\Export-ADGroupMembers.ps1 -GroupName "VPN-Users" -OutputPath "C:\Reports\vpn-users.csv" -IncludeNested
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$GroupName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNested
)

# Import AD module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Error "ActiveDirectory module not available. Install RSAT or run on a domain controller."
    exit 1
}

# Set default output path if not specified
if (-not $OutputPath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = ".\$GroupName`_Members_$timestamp.csv"
}

# Verify group exists
try {
    $group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
    Write-Host "Found group: $($group.DistinguishedName)" -ForegroundColor Green
}
catch {
    Write-Error "Group '$GroupName' not found in Active Directory."
    exit 1
}

# Get group members
Write-Host "Retrieving group members..." -ForegroundColor Cyan

try {
    if ($IncludeNested) {
        $members = Get-ADGroupMember -Identity $GroupName -Recursive -ErrorAction Stop |
            Where-Object { $_.objectClass -eq 'user' }
    }
    else {
        $members = Get-ADGroupMember -Identity $GroupName -ErrorAction Stop |
            Where-Object { $_.objectClass -eq 'user' }
    }
}
catch {
    Write-Error "Failed to retrieve group members: $_"
    exit 1
}

if ($members.Count -eq 0) {
    Write-Warning "No user members found in group '$GroupName'."
    exit 0
}

Write-Host "Found $($members.Count) user(s)" -ForegroundColor Cyan

# Get detailed user properties
$users = foreach ($member in $members) {
    try {
        Get-ADUser -Identity $member.SamAccountName -Properties `
            DisplayName,
            EmailAddress,
            Department,
            Title,
            Manager,
            Enabled,
            LastLogonDate,
            Created,
            Description |
        Select-Object @{N='SamAccountName';E={$_.SamAccountName}},
                      @{N='DisplayName';E={$_.DisplayName}},
                      @{N='EmailAddress';E={$_.EmailAddress}},
                      @{N='Department';E={$_.Department}},
                      @{N='Title';E={$_.Title}},
                      @{N='Manager';E={if($_.Manager){(Get-ADUser $_.Manager).Name}else{''}}},
                      @{N='Enabled';E={$_.Enabled}},
                      @{N='LastLogonDate';E={$_.LastLogonDate}},
                      @{N='Created';E={$_.Created}},
                      @{N='Description';E={$_.Description}}
    }
    catch {
        Write-Warning "Could not retrieve details for user: $($member.SamAccountName)"
    }
}

# Export to CSV
try {
    $users | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "`nExported $($users.Count) users to: $OutputPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export CSV: $_"
    exit 1
}
