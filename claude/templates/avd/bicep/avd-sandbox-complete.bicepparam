// ============================================================================
// AVD Sandbox - Complete Deployment Parameters
// Environment: Test/Sandbox
// Description: Deploy complete AVD environment from scratch
// ============================================================================

using 'avd-sandbox-complete.bicep'

// ============================================================================
// Environment Configuration
// ============================================================================

param environmentPrefix = 'sbx'
param projectName = 'avd01'
param location = 'australiasoutheast'

// ============================================================================
// Network Configuration
// ============================================================================

param vnetAddressPrefix = '10.100.0.0/16'
param avdSubnetPrefix = '10.100.1.0/24'
param enableBastionSubnet = false  // Set to true if you need Bastion

// ============================================================================
// Host Pool Configuration
// ============================================================================

param hostPoolType = 'Pooled'
param loadBalancerType = 'BreadthFirst'
param maxSessionLimit = 10
param startVMOnConnect = true

// ============================================================================
// Session Host Configuration
// ============================================================================

param sessionHostCount = 1
param vmSize = 'Standard_D2s_v3'
param adminUsername = 'avdadmin'
// IMPORTANT: Admin password must be provided at deployment time
// Option 1: Command line (recommended for testing)
//   az deployment group create ... --parameters adminPassword='YourSecurePassword123!'
// Option 2: Key Vault reference (recommended for production)
//   param adminPassword = getSecret('<subscription-id>', '<keyvault-rg>', '<keyvault-name>', 'avd-admin-password')
param adminPassword = ''  // Will prompt at deployment or override via CLI

param osDiskType = 'Premium_LRS'
param osDiskSizeGB = 128

param imageReference = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-avd'
  version: 'latest'
}

param enableAzureADJoin = true
param enableIntune = true

// ============================================================================
// FSLogix Configuration
// ============================================================================

param enableFSLogix = true
param fileShareQuotaGB = 256
param profileSizeMB = 30720
param enableOfficeContainer = true

// ============================================================================
// Azure AD Configuration (Optional - for Azure Files Kerberos)
// ============================================================================

// If you want Azure AD Kerberos authentication for FSLogix:
// 1. Uncomment and fill in these values
// 2. Otherwise, storage account key will be used

param azureADTenantId = ''  // Get from: (Get-AzContext).Tenant.Id
param azureADTenantName = ''  // e.g., 'contoso.onmicrosoft.com'

// ============================================================================
// RBAC Configuration (Optional)
// ============================================================================

// If you have Azure AD groups for AVD users:
// 1. Uncomment and fill in group Object IDs
// 2. Otherwise, assign permissions manually after deployment

param avdUsersGroupObjectId = ''  // Get from: (Get-AzADGroup -DisplayName "AVD-Users").Id
param avdAdminsGroupObjectId = ''  // Get from: (Get-AzADGroup -DisplayName "AVD-Admins").Id

// ============================================================================
// Tags
// ============================================================================

param tags = {
  Environment: 'Test'
  Application: 'AVD'
  Project: 'Sandbox'
  Owner: 'AVD Team'
  CostCenter: 'IT-Test'
  ManagedBy: 'Bicep'
  DeploymentType: 'Sandbox'
}
