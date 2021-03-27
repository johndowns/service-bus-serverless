@description('The location into which the Application Insights resources should be deployed.')
param location string

@description('The name of the Application Insights instance to deploy.')
param applicationInsightsName string

resource applicationInsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output instrumentationKey string = applicationInsights.properties.InstrumentationKey
