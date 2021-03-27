@description('The location into which the Azure Functions resources should be deployed.')
param location string

@description('The name of the Azure Functions application to create. This must be globally unique.')
param appName string

@description('The Service Bus connection string to use when receiving messages.')
@secure()
param serviceBusConnectionString string

@description('The name of the Azure Storage account that the Azure Functions app should use for metadata.')
param functionStorageAccountName string

@description('The instrumentation key used to identify Application Insights telemetry.')
param applicationInsightsInstrumentationKey string

@description('Additional configuration settings that should be added to the App Service application settings.')
param extraConfiguration object = {}

var serviceBusConnectionAppSettingName = 'ServiceBusConnection'
var functionRuntime = 'dotnet'
var extraConfigurationArray = extraConfiguration == {} ? [] : array(extraConfiguration)

resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2021-01-01' existing = {
  name: functionStorageAccountName
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: appName
  location: location
  kind: 'functionapp'
  properties: {
    siteConfig: {
      appSettings: union(extraConfigurationArray, [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionStorageAccount.id, functionStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionStorageAccount.id, functionStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${applicationInsightsInstrumentationKey}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionRuntime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'AzureWebJobsDisableHomepage' // This hides the default Azure Functions homepage, which means that Front Door health probe traffic is significantly reduced.
          value: 'true'
        }
        {
          name: serviceBusConnectionAppSettingName
          value: serviceBusConnectionString
        }
      ])
    }
    httpsOnly: true
  }
}

output functionAppHostName string = functionApp.properties.defaultHostName
output serviceBusConnectionAppSettingName string = serviceBusConnectionAppSettingName
