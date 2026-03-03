# Intune Policy Configuration Reporter

Automatically extracts and reports on Intune policies starting with "Orro" using Microsoft Graph API.

**Available in TWO versions:**
- 🐍 **Python version** - Cross-platform, requires Python runtime (this file)
- ⚡ **PowerShell version** - Windows native, no Python needed ([see PowerShell README](README_PowerShell.md))

Choose the version that best fits your environment and expertise.

## Features

- ✅ Extracts Device Configuration Policies
- ✅ Extracts Device Compliance Policies
- ✅ Extracts App Protection Policies (iOS, Android, Windows)
- ✅ Extracts Configuration Profiles (Settings Catalog, Administrative Templates)
- ✅ Filters policies starting with "Orro" (or custom prefix)
- ✅ Generates professional Word document report with:
  - Executive summary
  - Detailed policy configurations
  - Assignment information
  - Settings details

## Prerequisites

### 1. Azure AD App Registration

You need to create an Azure AD App Registration with the following permissions:

1. Go to [Azure Portal](https://portal.azure.com) → Azure Active Directory → App registrations
2. Click "New registration"
3. Name: `Intune Policy Reporter` (or any name)
4. Supported account types: "Accounts in this organizational directory only"
5. Click "Register"

### 2. Configure API Permissions

After creating the app:

1. Go to "API permissions"
2. Click "Add a permission" → Microsoft Graph → Application permissions
3. Add these permissions:
   - `DeviceManagementConfiguration.Read.All`
   - `DeviceManagementApps.Read.All`
   - `DeviceManagementManagedDevices.Read.All`
4. Click "Grant admin consent" (requires admin)

### 3. Create Client Secret

1. Go to "Certificates & secrets"
2. Click "New client secret"
3. Description: `Intune Reporter Secret`
4. Expires: Choose duration (recommend 12-24 months)
5. Click "Add"
6. **IMPORTANT**: Copy the secret value immediately (you can't see it again)

### 4. Collect Required Information

You'll need:
- **Tenant ID**: Found in "Overview" section of your app registration
- **Client ID** (Application ID): Found in "Overview" section
- **Client Secret**: The value you copied in step 3

## Installation

Install required Python packages:

```bash
pip install msal python-docx requests
```

## Usage

### Basic Usage

```bash
python intune_policy_reporter.py \
  --tenant-id YOUR_TENANT_ID \
  --client-id YOUR_CLIENT_ID \
  --client-secret YOUR_CLIENT_SECRET
```

### Custom Options

```bash
# Custom prefix (instead of "Orro")
python intune_policy_reporter.py \
  --tenant-id YOUR_TENANT_ID \
  --client-id YOUR_CLIENT_ID \
  --client-secret YOUR_CLIENT_SECRET \
  --prefix "CustomPrefix"

# Custom output file
python intune_policy_reporter.py \
  --tenant-id YOUR_TENANT_ID \
  --client-id YOUR_CLIENT_ID \
  --client-secret YOUR_CLIENT_SECRET \
  --output "My_Report.docx"
```

### Using Environment Variables (Recommended for Security)

Create a `.env` file or set environment variables:

```bash
export INTUNE_TENANT_ID="your-tenant-id"
export INTUNE_CLIENT_ID="your-client-id"
export INTUNE_CLIENT_SECRET="your-client-secret"
```

Then create a wrapper script:

```bash
python intune_policy_reporter.py \
  --tenant-id "$INTUNE_TENANT_ID" \
  --client-id "$INTUNE_CLIENT_ID" \
  --client-secret "$INTUNE_CLIENT_SECRET"
```

## Output

The tool generates a Word document (`Intune_Orro_Configuration_Report.docx` by default) containing:

1. **Title Page**
   - Organization name
   - Generation timestamp
   - Filter criteria

2. **Executive Summary**
   - Count of each policy type found

3. **Detailed Sections** for each policy type:
   - Device Configurations
   - Compliance Policies
   - App Protection Policies
   - Configuration Profiles

4. **Individual Policy Details**:
   - Display name
   - Description
   - Platform
   - Creation/modification dates
   - Assignments
   - Configuration settings (JSON format)

## Troubleshooting

### Authentication Failed

- Verify tenant ID, client ID, and client secret are correct
- Ensure admin consent was granted for API permissions
- Check that the app registration is in the correct tenant

### No Policies Found

- Verify policies exist with names starting with "Orro"
- Check API permissions are granted and consented
- Ensure the service principal has access to Intune policies

### Missing Permissions Error

- Go back to Azure Portal → App Registration → API permissions
- Ensure all required permissions are added and admin consent is granted

## Security Notes

- **Never commit credentials to version control**
- Use environment variables or secure credential storage
- Rotate client secrets regularly
- Limit app registration permissions to read-only
- Review Azure AD sign-in logs periodically

## Policy Types Covered

| Policy Type | API Endpoint | Description |
|-------------|--------------|-------------|
| Device Configurations | `/deviceManagement/deviceConfigurations` | Platform-specific device settings |
| Compliance Policies | `/deviceManagement/deviceCompliancePolicies` | Device compliance requirements |
| App Protection Policies | `/deviceAppManagement/*ManagedAppProtections` | iOS, Android, Windows app policies |
| Configuration Profiles | `/deviceManagement/configurationPolicies` | Settings Catalog, Admin Templates |

## Example Output

```
Intune Configuration Report
===========================
Organization: Orro
Generated: 2025-11-18 14:30
Filter: Policies starting with "Orro"

Executive Summary
-----------------
Policy Type              | Count
Device Configurations    | 5
Compliance Policies      | 3
App Protection Policies  | 2
Configuration Profiles   | 8

[Detailed sections follow...]
```

## Support

For issues or questions:
1. Check Azure AD app registration setup
2. Verify API permissions and admin consent
3. Review troubleshooting section above
4. Check Microsoft Graph API documentation
