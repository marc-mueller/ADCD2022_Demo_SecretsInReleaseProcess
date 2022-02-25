@minLength(1)
@maxLength(11)
param storageAccountName string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Premium_LRS'
])
param storageAccountType string = 'Standard_LRS'

@minLength(1)
@maxLength(63)
param storageContainerName string

@description('Specifies the name of the key vault.')
@minLength(1)
@maxLength(11)
param keyVaultName string

@description('Specifies whether the key vault is a standard vault or a premium vault.')
@allowed([
  'standard'
  'premium'
])
param keyVaultSkuName string = 'standard'

@description('Specifies whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
@allowed([
  true
  false
])
param keyVaultEnabledForTemplateDeployment bool = false

@description('Specifies the Azure Active Directory tenant ID that should be used for authenticating requests to the key vault. Get it by using Get-AzSubscription cmdlet.')
param keyVaultTenantId string = subscription().tenantId

@description('Specifies the name of the secret that you want to create.')
param keyVaultSecretName string

@description('Specifies the value of the secret that you want to create.')
@secure()
param keyVaultSecretValue string

param location string = resourceGroup().location

@description('Specifies a list of object ID of a user, service principal or security group in the Azure Active Directory tenant for the vault with reader permissions on secrets. The object ID must be unique for the list of access policies. Get it by using Get-AzADUser or Get-AzADServicePrincipal cmdlets.')
param readerObjectIds array

@description('Specifies a list of object ID of a user, service principal or security group in the Azure Active Directory tenant for the vault with admin permissions on secrets. The object ID must be unique for the list of access policies. Get it by using Get-AzADUser or Get-AzADServicePrincipal cmdlets.')
param adminObjectIds array

var storageAccountUniqueName = '${storageAccountName}${uniqueString(resourceGroup().id)}'
var keyVaultUniqueName = '${keyVaultName}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2018-07-01' = {
  name: storageAccountUniqueName
  location: location
  kind: 'Storage'
  sku: {
    name: storageAccountType
  }
  properties: {
    supportsHttpsTrafficOnly: true
  }
  tags: {
    'created-by': 'AzureRM.FirstSteps'
  }
  dependsOn: []
}

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-07-01' = {
  name: '${storageAccountUniqueName}/default/${storageContainerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccount
  ]
}

resource keyVault 'Microsoft.KeyVault/vaults@2018-02-14' = {
  name: keyVaultUniqueName
  location: location
  properties: {
    enabledForTemplateDeployment: keyVaultEnabledForTemplateDeployment
    tenantId: keyVaultTenantId
    accessPolicies: union(readerPolicies, adminPolicies)
    sku: {
      name: keyVaultSkuName
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

var readerPolicies = [for objectId in readerObjectIds: {
  objectId: objectId
  tenantId: keyVaultTenantId
  permissions: {
    secrets: [
      'get'
      'list'
    ]
  }
}]

var adminPolicies = [for objectId in adminObjectIds: {
  objectId: objectId
  tenantId: keyVaultTenantId
  permissions: {
    secrets: [
      'backup'
      'delete'
      'get'
      'list'
      'purge'
      'recover'
      'restore'
      'set'
    ]
  }
}]

resource keyVaultDemoSecret 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  parent: keyVault
  name: keyVaultSecretName
  properties: {
    value: keyVaultSecretValue
  }
}

resource keyVaultConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  parent: keyVault
  name: 'ConnectionString'
  properties: {
    contentType: 'text/plain'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountUniqueName};AccountKey=${listKeys(storageAccount.id, providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).keys[0].value};'
  }
}
