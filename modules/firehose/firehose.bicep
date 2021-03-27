@description('The region into which the resources should be deployed.')
param location string

@description('The name of the Azure Functions application in which to create the functions. This must be globally unique.')
param functionAppName string

@description('The name of the Azure Storage account that the Azure Functions app should use for metadata.')
param functionStorageAccountName string

@description('The instrumentation key used to identify Application Insights telemetry.')
param applicationInsightsInstrumentationKey string

@description('The connection string to use when connecting to the Service Bus namespace.')
@secure()
param serviceBusConnectionString string

@description('The name of the firehose queue.')
param firehoseQueueName string

@description('The name of the Azure Storage account to deploy for storing the firehose messages. This must be globally unique.')
param firehoseStorageAccountName string

@description('The name of the SKU to use when creating the Azure Storage account for storing the firehose messages.')
param firehoseStorageAccountSkuName string

var containerName = 'firehose'
var containerImmutabilityPeriodSinceCreationInDays = 365

// Create a storage account and immutable container for storing the firehose messages.
module firehoseStorageAccountModule 'storage.bicep' = {
  name: 'firehoseStorageAccountModule'
  params: {
    location: location
    storageAccountName: firehoseStorageAccountName
    storageAccountSkuName: firehoseStorageAccountSkuName
    storageAccountAccessTier: 'Cool'
    containerName: containerName
    containerImmutabilityPeriodSinceCreationInDays: containerImmutabilityPeriodSinceCreationInDays
  }
}

// Create the function app and function to listen to the firehose queue and write the messages to the storage container.
module firehoseFunctionModule 'function.bicep' = {
  name: 'firehoseFunctionModule'
  dependsOn: [
    firehoseStorageAccountModule
  ]
  params: {
    location: location
    functionAppName: functionAppName
    functionStorageAccountName: functionStorageAccountName
    firehoseStorageAccountName: firehoseStorageAccountName
    firehoseContainerName: containerName
    applicationInsightsInstrumentationKey: applicationInsightsInstrumentationKey
    serviceBusConnectionString: serviceBusConnectionString
    firehoseQueueName: firehoseQueueName
  }
}
