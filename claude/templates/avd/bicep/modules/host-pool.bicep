// ============================================================================
// AVD Host Pool Module
// Author: Maia Azure Architect Agent
// Version: 1.0.0
// Description: Creates AVD Host Pool with registration token
// ============================================================================

@description('Host pool name')
param hostPoolName string

@description('Azure region')
param location string

@description('Friendly name for the host pool')
param friendlyName string = ''

@description('Description of the host pool')
param hostPoolDescription string = 'AVD Host Pool'

@description('Host pool type')
@allowed([
  'Personal'
  'Pooled'
])
param hostPoolType string = 'Pooled'

@description('Load balancer type (for Pooled)')
@allowed([
  'BreadthFirst'
  'DepthFirst'
  'Persistent'
])
param loadBalancerType string = 'BreadthFirst'

@description('Max session limit per host')
param maxSessionLimit int = 10

@description('Preferred app group type')
@allowed([
  'Desktop'
  'RailApplications'
])
param preferredAppGroupType string = 'Desktop'

@description('Start VM on connect')
param startVMOnConnect bool = true

@description('Validation environment')
param validationEnvironment bool = false

@description('Custom RDP properties')
param customRdpProperty string = 'audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:0;redirectsmartcards:i:0;screen mode id:i:2;'

@description('Token expiration time in hours from now')
param tokenExpirationHours int = 24

@description('Base time for token expiration calculation')
param baseTime string = utcNow()

@description('Tags')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

var tokenExpirationTime = dateTimeAdd(baseTime, 'PT${tokenExpirationHours}H')

// ============================================================================
// Resources
// ============================================================================

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
  name: hostPoolName
  location: location
  tags: tags
  properties: {
    friendlyName: empty(friendlyName) ? hostPoolName : friendlyName
    description: hostPoolDescription
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    maxSessionLimit: maxSessionLimit
    preferredAppGroupType: preferredAppGroupType
    startVMOnConnect: startVMOnConnect
    validationEnvironment: validationEnvironment
    customRdpProperty: customRdpProperty
    registrationInfo: {
      expirationTime: tokenExpirationTime
      registrationTokenOperation: 'Update'
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Host pool resource ID')
output hostPoolId string = hostPool.id

@description('Host pool name')
output hostPoolName string = hostPool.name

@description('Registration token - use listRegistrationTokens to retrieve')
#disable-next-line outputs-should-not-contain-secrets
output registrationToken string = hostPool.listRegistrationTokens().value[0].token

@description('Token expiration time')
output tokenExpiration string = tokenExpirationTime
