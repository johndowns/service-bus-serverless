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

@description('The list of topic names to create functions for.')
param serviceBusTopicNames array

// Create a function app.
module senderFunctionAppModule '../function-app.bicep' = {
  name: 'senderFunctionAppModule'
  params: {
    location: location
    appName: functionAppName
    functionStorageAccountName: functionStorageAccountName
    applicationInsightsInstrumentationKey: applicationInsightsInstrumentationKey
    serviceBusConnectionString: serviceBusConnectionString
  }
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' existing = {
  name: functionAppName
}

// Create a function for each topic subscription.
resource topicFunction 'Microsoft.Web/sites/functions@2020-06-01' = [for serviceBusTopicName in serviceBusTopicNames: {
  name: 'Send-${serviceBusTopicName}'
  parent: functionApp
  properties: {
    config: {
      disabled: false
      bindings: [
        {
          name: 'req'
          type: 'httpTrigger'
          direction: 'in'
          authLevel: 'anonymous'
          methods: [
            'post'
          ]
        }
        {
          name: '$return'
          type: 'http'
          direction: 'out'
        }
        {
          name: 'outputMessage'
          type: 'serviceBus'
          topicName: serviceBusTopicName
          connection: senderFunctionAppModule.outputs.serviceBusConnectionAppSettingName
          direction: 'out'
        }
      ]
    }
    files: {
      'run.csx': '''
        #r "Newtonsoft.Json"

        using System.Net;
        using Microsoft.AspNetCore.Mvc;
        using Microsoft.Extensions.Primitives;
        using Newtonsoft.Json;

        public static async Task<IActionResult> Run(
          HttpRequest req,
          ILogger log,
          IAsyncCollector<string> outputMessage)
        {
            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();

            int.TryParse(req.Query["count"], out var count);
            
            for (var i = 0; i < count; i++)
            {
              await outputMessage.AddAsync(requestBody);
            }
            return new OkObjectResult($"Sent {count} message(s) to topic.");
        }
      '''
    }
  }
}]

output functionsUrls array = [for serviceBusTopicName in serviceBusTopicNames: {
  topicName: serviceBusTopicName
  url: 'https://${senderFunctionAppModule.outputs.functionAppHostName}/api/Send-${serviceBusTopicName}?count=5'
}]
