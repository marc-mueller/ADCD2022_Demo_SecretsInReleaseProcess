@description('Base name of the resource such as web app name and app service plan ')
@minLength(2)
param webAppName string = 'secretsdemo'

@description('The SKU of App Service Plan ')
param sku string = 'F1'

@description('The Runtime stack of current web app')
param linuxFxVersion string = 'DOTNETCORE|5.0'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Specifies the name of the key vault.')
@minLength(1)
@maxLength(11)
param keyVaultName string

var webAppPortalName_var = '${webAppName}-webapp'
var appServicePlanName_var = 'AppServicePlan-${webAppName}'
var keyVaultUniqueName = '${keyVaultName}${uniqueString(resourceGroup().id)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName_var
  location: location
  sku: {
    name: sku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppPortalName_var
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      webSocketsEnabled: true
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: '${keyVaultUniqueName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: reference(webApp.id, '2019-08-01', 'full').identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}
