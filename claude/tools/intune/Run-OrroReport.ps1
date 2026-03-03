<#
.SYNOPSIS
    Quick launcher for Intune Orro Policy Report
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$UseInteractive,
    [Parameter(Mandatory=$false)]
    [switch]$SaveCredentials
)

$credFile = "$env:USERPROFILE\.intune_reporter_creds.json"
$scriptPath = Join-Path $PSScriptRoot "Get-IntuneOrroReport.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Intune Orro Policy Reporter - Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Save credentials mode
if ($SaveCredentials) {
    Write-Host "Credential Setup" -ForegroundColor Yellow
    Write-Host "---------------" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You can use either:" -ForegroundColor White
    Write-Host "  1. Interactive authentication (recommended for getting started)" -ForegroundColor White
    Write-Host "  2. App-only authentication (recommended for automation)" -ForegroundColor White
    Write-Host ""

    $authType = Read-Host "Choose authentication type (1 or 2)"

    if ($authType -eq "1") {
        $creds = @{
            AuthType = "Interactive"
            TenantId = Read-Host "Enter Tenant ID (optional, press Enter to skip)"
        }
    } else {
        $creds = @{
            AuthType = "AppOnly"
            TenantId = Read-Host "Enter Tenant ID"
            ClientId = Read-Host "Enter Client ID"
            ClientSecret = Read-Host "Enter Client Secret" -AsSecureString | ConvertFrom-SecureString
        }
    }

    $creds | ConvertTo-Json | Out-File $credFile
    Write-Host ""
    Write-Host "Credentials saved to: $credFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run this script again without -SaveCredentials to generate reports" -ForegroundColor Cyan
    exit 0
}

# Load credentials or use interactive
if (Test-Path $credFile) {
    Write-Host "Loading saved credentials..." -ForegroundColor Yellow
    $creds = Get-Content $credFile | ConvertFrom-Json

    if ($UseInteractive -or $creds.AuthType -eq "Interactive") {
        Write-Host "Using interactive authentication..." -ForegroundColor Cyan
        Write-Host ""
        if ($creds.TenantId) {
            & $scriptPath -UseInteractive -TenantId $creds.TenantId
        } else {
            & $scriptPath -UseInteractive
        }
    } else {
        Write-Host "Using app-only authentication..." -ForegroundColor Cyan
        Write-Host ""
        $secureSecret = $creds.ClientSecret | ConvertTo-SecureString
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
        $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        & $scriptPath -TenantId $creds.TenantId -ClientId $creds.ClientId -ClientSecret $plainSecret
    }
} else {
    Write-Host "No saved credentials found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor White
    Write-Host "  1. Run with interactive authentication" -ForegroundColor White
    Write-Host "  2. Save credentials for future use" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "Choose option (1 or 2)"
    if ($choice -eq "2") {
        Write-Host ""
        & $PSCommandPath -SaveCredentials
    } else {
        Write-Host ""
        Write-Host "Using interactive authentication..." -ForegroundColor Cyan
        Write-Host ""
        & $scriptPath -UseInteractive
    }
}

Write-Host ""
Write-Host "To save credentials for future runs:" -ForegroundColor Yellow
Write-Host "  .\Run-OrroReport.ps1 -SaveCredentials" -ForegroundColor White
Write-Host ""
