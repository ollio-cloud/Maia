// ============================================================================
// AVD Session Host Deployment Parameters
// Target: pauseisavd-1
// Environment: Production - p-ause-mb-rg-avd
// ============================================================================

using 'avd-session-host-deploy.bicep'

// ============================================================================
// VM Configuration
// ============================================================================

param vmName = 'pauseisavd-1'
param location = 'australiasoutheast'
param vmSize = 'Standard_E8s_v5'
param adminUsername = 'avdadmin'
// param adminPassword = 'PROVIDED_AT_DEPLOY_TIME'

// ============================================================================
// Network Configuration
// ============================================================================

param subnetId = '/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-workloads/providers/Microsoft.Network/virtualNetworks/p-ause-mb-vn-workloads/subnets/App'

// ============================================================================
// AVD Host Pool Configuration
// ============================================================================

param hostPoolName = 'pauseisavdpool01'
// param hostPoolToken = 'GENERATED_AT_DEPLOY_TIME'

// ============================================================================
// VM Disk Configuration
// ============================================================================

param osDiskType = 'Premium_LRS'
param osDiskSizeGB = 128

// ============================================================================
// Security & Identity
// ============================================================================

param enableAzureADJoin = true
param enableIntune = true
param availabilityZone = ''  // Australia Southeast does not support Availability Zones

// ============================================================================
// Windows Image
// ============================================================================

param imageReference = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-avd'
  version: 'latest'
}

// ============================================================================
// FSLogix Configuration
// ============================================================================

param enableFSLogix = false  // Deploy VM first, add FSLogix later
param fslogixStorageAccountName = 'pauseisfslogix001'
param fslogixFileShareName = 'fslogix-profiles'
param fslogixProfileSizeMB = 30720
param fslogixEnableOfficeContainer = true
param fslogixDeleteLocalProfile = true
param fslogixPreventTempProfile = true
param fslogixPreventLoginOnFailure = false
param fslogixUseStorageKey = false  // Using Azure AD Kerberos authentication

// ============================================================================
// Tags
// ============================================================================

param tags = {
  Environment: 'Production'
  Application: 'AVD'
  HostPool: 'pauseisavdpool01'
  Component: 'SessionHost'
  CostCenter: 'IT'
  Owner: 'AVD Team'
  ManagedBy: 'Bicep'
}
