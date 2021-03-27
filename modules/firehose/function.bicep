@description('The region into which the resources should be deployed.')
param location string

@description('The name of the Azure Functions application in which to create the functions. This must be globally unique.')
param functionAppName string

@description('The name of the Azure Storage account that the Azure Functions app should use for metadata.')
param functionStorageAccountName string

@description('The name of the Azure Storage account to deploy for storing the firehose messages. This must be globally unique.')
param firehoseStorageAccountName string

@description('The name of the Azure Storage blob container for storing the firehose messages.')
param firehoseContainerName string

@description('The instrumentation key used to identify Application Insights telemetry.')
param applicationInsightsInstrumentationKey string

@description('The connection string to use when connecting to the Service Bus namespace.')
@secure()
param serviceBusConnectionString string

@description('The name of the firehose queue.')
param firehoseQueueName string

var functionName = 'ProcessFirehoseQueueMessage'
var firehoseStorageConnectionStringAppSettingName = 'FirehoseStorage'

// Get a reference to the firehose storage account.
resource firehoseStorageAccount 'Microsoft.Storage/storageAccounts@2021-01-01' existing = {
  name: firehoseStorageAccountName
}

// Create a function app and function to listen to the firehose queue and save the messages to the firehose storage account.
module firehoseFunctionAppModule '../function-app.bicep' = {
  name: 'firehoseFunctionAppModule'
  params: {
    location: location
    appName: functionAppName
    functionStorageAccountName: functionStorageAccountName
    applicationInsightsInstrumentationKey: applicationInsightsInstrumentationKey
    serviceBusConnectionString: serviceBusConnectionString
    extraConfiguration: {
      name: firehoseStorageConnectionStringAppSettingName
      value: 'DefaultEndpointsProtocol=https;AccountName=${firehoseStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(firehoseStorageAccount.id, firehoseStorageAccount.apiVersion).keys[0].value}'
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
    firehoseFunctionAppModule
  ]
  properties: {
    config: {
      disabled: false
      bindings: [
        {
          name: 'message'
          type: 'serviceBusTrigger'
          direction: 'in'
          queueName: firehoseQueueName
          connection: firehoseFunctionAppModule.outputs.serviceBusConnectionAppSettingName
        }
        {
          name: 'blobOutput'
          type: 'blob'
          direction: 'out'
          path: '${firehoseContainerName}/y={enqueuedTimeUtc.Year}/m={enqueuedTimeUtc.Month}/d={enqueuedTimeUtc.Day}/h={enqueuedTimeUtc.Hour}/{enqueuedTimeUtc}-{messageId}.json'
          connection: firehoseStorageConnectionStringAppSettingName
        }
      ]
    }
    files: {
      'run.csx': '''
        #r "Newtonsoft.Json"
        using System;
        using Newtonsoft.Json.Linq;

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
            out string blobOutput)
        {
            log.Info($"C# Service Bus trigger function processed message: {message}");

            var logEntry = new {
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
            JObject o = (JObject)JToken.FromObject(logEntry);
            blobOutput = o.ToString();
        }
      '''
    }
  }
}
