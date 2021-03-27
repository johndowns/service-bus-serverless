@description('The region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('The name of the Service Bus namespace to deploy. This must be globally unique.')
param serviceBusNamespaceName string = 'sb-${uniqueString(resourceGroup().id)}'

@description('The SKU of Service Bus to deploy.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param serviceBusSkuName string = 'Standard'

@description('An array specifying the names of topics that should be deployed.')
param serviceBusTopicNames array = [
  'sample1'
  'sample2'
]

@description('The name of the Azure Storage account to deploy for the Azure Functions apps to use for metadata. This must be globally unique.')
param functionAppStorageAccountName string = 'fn${uniqueString(resourceGroup().id)}'

@description('The name of the SKU to use when creating the Azure Storage account for the Azure Functions apps to use for metadata.')
param functionAppStorageAccountSkuName string = 'Standard_LRS'

@description('The name of the Azure Functions application to create for processing messages. This must be globally unique.')
param processorFunctionAppName string = 'fn-processor-${uniqueString(resourceGroup().id, 'processor')}'

@description('The name of the Azure Functions application to create for handling firehose messages. This must be globally unique.')
param firehoseFunctionAppName string = 'fn-firehose-${uniqueString(resourceGroup().id, 'firehose')}'

@description('The name of the Azure Functions application to create for handling dead-letter firehose messages. This must be globally unique.')
param deadLetterFirehoseFunctionAppName string = 'fn-deadletter-${uniqueString(resourceGroup().id, 'firehose')}'

@description('The name of the Azure Functions application to create for sending messages. This must be globally unique.')
param senderFunctionAppName string = 'fn-sender-${uniqueString(resourceGroup().id, 'sender')}'

@description('The name of the Azure Storage account to deploy for storing the firehose messages. This must be globally unique.')
param firehoseStorageAccountName string = 'firehose${uniqueString(resourceGroup().id, 'firehose')}'

@description('The name of the SKU to use when creating the Azure Storage account for storing the firehose messages.')
param firehoseStorageAccountSkuName string = 'Standard_LRS'

@description('The name of the Cosmos DB account to create for storing the dead-letter firehose messages. This must be globally unique.')
param deadLetterFirehoseCosmosDBAccountName string = 'deadletter${uniqueString(resourceGroup().id, 'deadletter')}'

var applicationInsightsName = 'ServerlessMessagingDemo'
var processingMaxDeliveryCount = 1 // If messages are failed to be processed, they won't be retried. Normally you would want to keep this at its default value of 10.

// Deploy the Service Bus resources.
module serviceBusModule 'modules/service-bus.bicep' = {
  name: 'serviceBusModule'
  params: {
    location: location
    namespaceName: serviceBusNamespaceName
    skuName: serviceBusSkuName
    topicNames: serviceBusTopicNames
    processingMaxDeliveryCount: processingMaxDeliveryCount
  }
}

// Deploy the shared Application Insights instance.
module applicationInsightsModule 'modules/application-insights.bicep' = {
  name: 'applicationInsightsModule'
  params: {
    location: location
    applicationInsightsName: applicationInsightsName
  }
}

// Deploy the shared Azure Storage account for all function apps to use for their metadata.

module functionAppStorageAccountModule 'modules/storage.bicep' = {
  name: 'functionAppStorageAccountModule'
  params: {
    location: location
    storageAccountName: functionAppStorageAccountName
    storageAccountSkuName: functionAppStorageAccountSkuName
  }
}

// Deploy the resources for processing the primary queue messages.
module processorsModule 'modules/processors/processors.bicep' = {
  name: 'processorsModule'
  params: {
    location: location
    functionAppName: processorFunctionAppName
    functionStorageAccountName: functionAppStorageAccountModule.outputs.storageAccountName
    applicationInsightsInstrumentationKey: applicationInsightsModule.outputs.instrumentationKey
    serviceBusConnectionString: serviceBusModule.outputs.processorConnectionString
    serviceBusTopicNames: serviceBusTopicNames
    processSubscriptionName: serviceBusModule.outputs.processSubscriptionName
  }
}

// Deploy the resources for processing the firehose queue messages.
module firehoseModule 'modules/firehose/firehose.bicep' = {
  name: 'firehoseModule'
  params: {
    location: location
    functionAppName: firehoseFunctionAppName
    functionStorageAccountName: functionAppStorageAccountModule.outputs.storageAccountName
    applicationInsightsInstrumentationKey: applicationInsightsModule.outputs.instrumentationKey
    serviceBusConnectionString: serviceBusModule.outputs.firehoseConnectionString
    firehoseQueueName: serviceBusModule.outputs.firehoseQueueName
    firehoseStorageAccountName: firehoseStorageAccountName
    firehoseStorageAccountSkuName: firehoseStorageAccountSkuName
  }
}

// Deploy the resources for processing the dead-lettered firehose queue messages.
module deadLetterFirehoseModule 'modules/dead-letter-firehose/dead-letter-firehose.bicep' = {
  name: 'deadLetterFirehoseModule'
  params: {
    location: location
    functionAppName: deadLetterFirehoseFunctionAppName
    functionStorageAccountName: functionAppStorageAccountModule.outputs.storageAccountName
    applicationInsightsInstrumentationKey: applicationInsightsModule.outputs.instrumentationKey
    serviceBusConnectionString: serviceBusModule.outputs.firehoseConnectionString
    deadLetterFirehoseQueueName: serviceBusModule.outputs.deadLetterFirehoseQueueName
    deadLetterFirehoseCosmosDBAccountName: deadLetterFirehoseCosmosDBAccountName
  }
}

// Deploy the resources for processing the primary queue messages.
module sendersModule 'modules/senders/senders.bicep' = {
  name: 'sendersModule'
  params: {
    location: location
    functionAppName: senderFunctionAppName
    functionStorageAccountName: functionAppStorageAccountModule.outputs.storageAccountName
    applicationInsightsInstrumentationKey: applicationInsightsModule.outputs.instrumentationKey
    serviceBusConnectionString: serviceBusModule.outputs.senderConnectionString
    serviceBusTopicNames: serviceBusTopicNames
  }
}

output senderFunctionsUrls array = sendersModule.outputs.functionsUrls
