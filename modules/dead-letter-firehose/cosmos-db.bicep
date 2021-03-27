@description('The region into which the resources should be deployed.')
param location string

@description('The name of the Cosmos DB account to create. This must be globally unique.')
param accountName string

@description('The name of the Cosmos DB database to create.')
param databaseName string

@description('The name of the Cosmos DB container to create.')
param containerName string

@description('The name of the document property containing the partition key.')
param containerPartitionKey string

var accountDefaultConsistencyLevel = 'Session'

resource account 'Microsoft.DocumentDB/databaseAccounts@2020-04-01' = {
  name: accountName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: accountDefaultConsistencyLevel
    }
    locations: [
      {
        locationName: location
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2020-04-01' = {
  name: databaseName
  parent: account
  properties: {
    resource: {
      id: databaseName
    }
    options: {}
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-03-01-preview' = {
  name: containerName
  parent: database
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        kind: 'Hash'
        paths: [
          containerPartitionKey
        ]
      }
    }
  }
}
