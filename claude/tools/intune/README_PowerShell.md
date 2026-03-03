# Intune Policy Reporter - PowerShell Edition

Generate comprehensive Intune configuration reports using PowerShell and Microsoft Graph API.

## Features

- ✅ Native PowerShell implementation
- ✅ Interactive OR app-only authentication
- ✅ Extracts all Intune policy types
- ✅ Filters policies by prefix (default: "Orro")
- ✅ Generates professional Word document reports
- ✅ Uses Microsoft Graph PowerShell modules
- ✅ No Python required

## Prerequisites

### 1. PowerShell Requirements

- **Windows PowerShell 5.1** or **PowerShell 7+**
- **Microsoft Word** installed (for document generation)

### 2. Required PowerShell Modules

The script will automatically install these if missing:
- `Microsoft.Graph.Authentication`
- `Microsoft.Graph.DeviceManagement`
- `Microsoft.Graph.DeviceManagement.Enrolment`

### 3. Authentication Options

Choose ONE of these authentication methods:

#### Option A: Interactive Authentication (Recommended for Getting Started)
- Uses your own user account
- Browser-based sign-in
- Requires Intune Administrator or Global Reader role
- **No Azure AD app registration needed**

#### Option B: App-Only Authentication (Recommended for Automation)
- Uses Azure AD app registration with client secret
- Requires setup (see below)
- Best for scheduled/automated reports

## Quick Start (Interactive Authentication)

### Step 1: Open PowerShell

Open PowerShell as Administrator:
```powershell
# Right-click PowerShell icon → "Run as Administrator"
```

### Step 2: Install Modules (First Time Only)

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser -Force
Install-Module Microsoft.Graph.DeviceManagement.Enrolment -Scope CurrentUser -Force
```

### Step 3: Run the Script

```powershell
# Navigate to the script directory
cd C:\Users\olli.ojala\maia\claude\tools\intune

# Run with interactive authentication
.\Get-IntuneOrroReport.ps1 -UseInteractive
```

A browser window will open for sign-in. The report will be generated as `Intune_Orro_Configuration_Report.docx`.

## Usage Examples

### Interactive Authentication (Simplest)

```powershell
# Default: filters for "Orro" policies
.\Get-IntuneOrroReport.ps1 -UseInteractive

# Custom prefix
.\Get-IntuneOrroReport.ps1 -UseInteractive -Prefix "CustomPrefix"

# Custom output location
.\Get-IntuneOrroReport.ps1 -UseInteractive -OutputPath "C:\Reports\MyReport.docx"

# Specific tenant
.\Get-IntuneOrroReport.ps1 -UseInteractive -TenantId "your-tenant-id"
```

### App-Only Authentication (for Automation)

```powershell
# Using service principal credentials
.\Get-IntuneOrroReport.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret"

# With custom prefix
.\Get-IntuneOrroReport.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret" `
    -Prefix "Orro"
```

## Setting Up App-Only Authentication (Optional)

If you want to use automated/scheduled reports:

### Step 1: Create Azure AD App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **"New registration"**
4. Name: `Intune Policy Reporter`
5. Supported account types: **"Accounts in this organizational directory only"**
6. Click **"Register"**

### Step 2: Add API Permissions

1. Go to **"API permissions"**
2. Click **"Add a permission"** → **Microsoft Graph** → **Application permissions**
3. Add these permissions:
   - `DeviceManagementConfiguration.Read.All`
   - `DeviceManagementApps.Read.All`
   - `DeviceManagementManagedDevices.Read.All`
4. Click **"Grant admin consent for [Your Organization]"**

### Step 3: Create Client Secret

1. Go to **"Certificates & secrets"**
2. Click **"New client secret"**
3. Description: `Intune Reporter Secret`
4. Expires: Choose duration (12-24 months)
5. Click **"Add"**
6. **IMPORTANT**: Copy the secret **Value** immediately

### Step 4: Collect Information

From the **Overview** page, note:
- **Directory (tenant) ID**
- **Application (client) ID**
- **Client secret value** (from Step 3)

### Step 5: Create Credential File (Optional)

For convenience, create a credential file:

```powershell
# Create secure credential file
$tenantId = "your-tenant-id"
$clientId = "your-client-id"
$clientSecret = "your-client-secret"

$credentials = @{
    TenantId = $tenantId
    ClientId = $clientId
    ClientSecret = $clientSecret
}

$credentials | ConvertTo-Json | Out-File "$env:USERPROFILE\.intune_reporter_creds.json"
```

Then create a wrapper script:

```powershell
# Load-IntuneReport.ps1
$creds = Get-Content "$env:USERPROFILE\.intune_reporter_creds.json" | ConvertFrom-Json

.\Get-IntuneOrroReport.ps1 `
    -TenantId $creds.TenantId `
    -ClientId $creds.ClientId `
    -ClientSecret $creds.ClientSecret
```

## Output Report

The generated Word document includes:

### 1. Title Page
- Organization name
- Generation timestamp
- Filter criteria

### 2. Executive Summary Table
- Count of each policy type found
- Quick overview

### 3. Detailed Sections

#### Device Configuration Policies
- Platform-specific settings
- Wi-Fi, VPN, Email profiles
- Restrictions, features

#### Device Compliance Policies
- Compliance requirements
- Platform-specific rules
- Actions for non-compliance

#### Configuration Policies
- Settings Catalog policies
- Administrative Templates
- Custom configurations

#### App Protection Policies
- iOS app protection
- Android app protection
- Windows app protection

### 4. Individual Policy Details
For each policy:
- Display name
- Description
- Platform type
- Created/modified dates
- Policy ID
- Full configuration settings (JSON format)

## Scheduling Reports (Optional)

### Create Scheduled Task

```powershell
# Create a scheduled task to run daily at 8 AM
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File `"C:\Users\olli.ojala\maia\claude\tools\intune\Get-IntuneOrroReport.ps1`" -TenantId `"xxx`" -ClientId `"yyy`" -ClientSecret `"zzz`""

$trigger = New-ScheduledTaskTrigger -Daily -At 8am

Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName "Intune Orro Report" `
    -Description "Daily Intune configuration report for Orro policies"
```

## Troubleshooting

### "Module not found" Error

```powershell
# Install modules manually
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### "Connect-MgGraph: Insufficient privileges" Error

- Ensure you have Intune Administrator or Global Reader role
- For app-only auth: verify API permissions are granted and admin consent is provided

### "Word not installed" Error

- Install Microsoft Word
- Or modify script to output to different format (CSV, JSON, etc.)

### No Policies Found

- Verify policies exist with names starting with "Orro"
- Check your account has permission to view Intune policies
- Try running with `-Prefix "*"` to see all policies

### Authentication Timeout

```powershell
# Disconnect and reconnect
Disconnect-MgGraph
.\Get-IntuneOrroReport.ps1 -UseInteractive
```

## Comparison: PowerShell vs Python

| Feature | PowerShell | Python |
|---------|-----------|--------|
| **Installation** | Native on Windows | Requires Python runtime |
| **Modules** | Microsoft.Graph modules | msal, python-docx, requests |
| **Authentication** | Interactive or app-only | App-only only |
| **Word Integration** | Native COM automation | python-docx library |
| **Best For** | Windows admins, one-off reports | Cross-platform, automation |
| **Learning Curve** | Lower for Windows admins | Lower for developers |

## Security Best Practices

- ✅ Use interactive auth for manual reports
- ✅ Use app-only auth for scheduled reports
- ✅ Store credentials securely (not in scripts)
- ✅ Use Azure Key Vault for production
- ✅ Rotate client secrets regularly
- ✅ Limit app permissions to read-only
- ✅ Monitor Azure AD sign-in logs

## Advanced Usage

### Filter Multiple Prefixes

```powershell
# Run for multiple organizations
$prefixes = @("Orro", "Contoso", "Fabrikam")

foreach ($prefix in $prefixes) {
    .\Get-IntuneOrroReport.ps1 `
        -UseInteractive `
        -Prefix $prefix `
        -OutputPath "Intune_${prefix}_Report.docx"
}
```

### Export to CSV Instead

Modify the script to export to CSV:

```powershell
# After fetching policies, add:
$allPolicies = @()
$allPolicies += $policies.DeviceConfigurations | Select-Object displayName, '@odata.type', createdDateTime
$allPolicies += $policies.CompliancePolicies | Select-Object displayName, '@odata.type', createdDateTime

$allPolicies | Export-Csv -Path "Intune_Policies.csv" -NoTypeInformation
```

## Support

For issues:
1. Check you have the latest Microsoft.Graph modules
2. Verify API permissions and consent
3. Review troubleshooting section
4. Check Microsoft Graph API status

## Related Files

- **Python version**: `intune_policy_reporter.py`
- **Setup guide**: `setup_guide.py` (Python)
- **General docs**: `README.md`

## Version History

- **v1.0** - Initial PowerShell implementation
  - Interactive and app-only authentication
  - Word document generation
  - Support for all major policy types
