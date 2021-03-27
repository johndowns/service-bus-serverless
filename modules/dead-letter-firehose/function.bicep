@description('The region into which the resources should be deployed.')
param location string

@description('The name of the Azure Functions application in which to create the functions. This must be globally unique.')
param functionAppName string

@description('The name of the Azure Storage account that the Azure Functions app should use for metadata.')
param functionStorageAccountName string

@description('The name of the Cosmos DB account that should contain the dead-letter firehose messages.')
param deadLetterFirehoseCosmosDBAccountName string

@description('The name of the Cosmos DB database that should contain the dead-letter firehose messages.')
param deadLetterFirehoseCosmosDBDatabaseName string

@description('The name of the Cosmos DB container that should contain the dead-letter firehose messages.')
param deadLetterFirehoseCosmosDBContainerName string

@description('The instrumentation key used to identify Application Insights telemetry.')
param applicationInsightsInstrumentationKey string

@description('The connection string to use when connecting to the Service Bus namespace.')
@secure()
param serviceBusConnectionString string

@description('The name of the dead-letter firehose queue.')
param deadLetterFirehoseQueueName string

var functionName = 'ProcessDeadLetterFirehoseQueueMessage'
var firehoseStorageConnectionStringAppSettingName = 'FirehoseStorage'

// Get a reference to the dead-letter firehose Cosmos DB account.
resource deadLetterFirehoseCosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2020-04-01' existing = {
  name: deadLetterFirehoseCosmosDBAccountName
}

// Create a function app and function to listen to the firehose queue and save the messages to the firehose storage account.
module deadLetterFirehoseFunctionAppModule '../function-app.bicep' = {
  name: 'deadLetterFirehoseFunctionAppModule'
  params: {
    location: location
    appName: functionAppName
    functionStorageAccountName: functionStorageAccountName
    applicationInsightsInstrumentationKey: applicationInsightsInstrumentationKey
    serviceBusConnectionString: serviceBusConnectionString
    extraConfiguration: {
      name: firehoseStorageConnectionStringAppSettingName
      value: listConnectionStrings(deadLetterFirehoseCosmosDBAccount.id, deadLetterFirehoseCosmosDBAccount.apiVersion).connectionStrings[0].connectionString
    }
  }
}

// Get a reference to the function app that was created, so we can use it below.
resource functionApp 'Microsoft.Web/sites@2020-06-01' existing = {
  name: functionAppName
}

// Create a function.
resource function 'Microsoft.Web/sites/functions@2020-06-01' = {
  name: functionName
  parent: functionApp
  dependsOn: [
    deadLetterFirehoseFunctionAppModule
  ]
  properties: {
    config: {
      disabled: false
      bindings: [
        {
          name: 'message'
          type: 'serviceBusTrigger'
          direction: 'in'
          queueName: deadLetterFirehoseQueueName
          connection: deadLetterFirehoseFunctionAppModule.outputs.serviceBusConnectionAppSettingName
        }
        {
          name: 'deadLetterDocument'
          type: 'cosmosDB'
          databaseName: deadLetterFirehoseCosmosDBDatabaseName
          collectionName: deadLetterFirehoseCosmosDBContainerName
          direction: 'out'
          connectionStringSetting: firehoseStorageConnectionStringAppSettingName
        }
      ]
    }
    files: {
      'run.csx': '''
        using System;

        public static void Run(
            string contentType,
            string correlationId,
            string deadLetterSource,
            Int32 deliveryCount,
            DateTime enqueuedTimeUtc,
            DateTime expiresAtUtc,
            string label,
            string messageId,
            string replyTo,
            long sequenceNumber,
            string to,
            IDictionary<string, object> userProperties,
            string message,
            TraceWriter log,
            out object deadLetterDocument)
        {
            deadLetterDocument = new {
              contentType = contentType,
              correlationId = correlationId,
              deadLetterSource = deadLetterSource,
              deliveryCount = deliveryCount,
              enqueuedTimeUtc = enqueuedTimeUtc,
              expiresAtUtc = expiresAtUtc,
              label = label,
              messageId = messageId,
              replyTo = replyTo,
              sequenceNumber = sequenceNumber,
              to = to,
              userProperties = userProperties,
              message = message
            };
        }
      '''
    }
  }
}
