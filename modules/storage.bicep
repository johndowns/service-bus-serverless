@description('The region into which the Azure Storage resources should be deployed.')
param location string

@description('The name of the Azure Storage account to deploy. This must be globally unique.')
param storageAccountName string

@description('The name of the SKU to use when creating the Azure Storage account.')
param storageAccountSkuName string

@description('The name of the access tier to use when creating the Azure Storage account.')
@allowed([
  'Cool'
  'Hot'
])
param storageAccountAccessTier string = 'Hot'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSkuName
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: storageAccountAccessTier
  }
}

output storageAccountName string = storageAccountName
