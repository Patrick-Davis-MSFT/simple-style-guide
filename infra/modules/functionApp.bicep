param name string
param location string
param appServicePlanId string
param appInsightsConnectionString string
param storageAccountName string
param vnetResourceId string
param webAppHostname string
param foundryProjectEndpoint string = ''
param foundryAgentId string = ''
param foundryAgentName string = ''
param foundryAgentVersion string = ''
param foundryProjectResourceId string = ''
param foundryResourceId string = ''
param foundryOpenAIApiVersion string = ''

var storageDnsSuffix = environment().suffixes.storage

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientCertEnabled: false
    clientCertMode: 'Optional'
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'Node|22'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
          'http://localhost:3000'
          'http://localhost:8080'
          'http://localhost:5000'
          'http://localhost:8000'
          'https://${webAppHostname}'
        ]
      }
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'FUNCTIONS_NODE_BLOCK_ON_ENTRY_POINT_ERROR'
          value: 'true'
        }
        {
          name: 'AzureWebJobsFeatureFlags'
          value: 'EnableWorkerIndexing'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: 'https://${storageAccountName}.blob.${storageDnsSuffix}'
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: 'https://${storageAccountName}.queue.${storageDnsSuffix}'
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: 'https://${storageAccountName}.table.${storageDnsSuffix}'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        {
          name: 'VNET_RESOURCE_ID'
          value: vnetResourceId
        }
        {
          name: 'AZURE_EXISTING_AIPROJECT_ENDPOINT'
          value: foundryProjectEndpoint
        }
        {
          name: 'AZURE_EXISTING_AGENT_ID'
          value: foundryAgentId
        }
        {
          name: 'AZURE_FOUNDRY_AGENT_NAME'
          value: foundryAgentName
        }
        {
          name: 'AZURE_FOUNDRY_AGENT_VERSION'
          value: foundryAgentVersion
        }
        {
          name: 'AZURE_EXISTING_AIPROJECT_RESOURCE_ID'
          value: foundryProjectResourceId
        }
        {
          name: 'AZURE_EXISTING_RESOURCE_ID'
          value: foundryResourceId
        }
        {
          name: 'OPENAI_API_VERSION'
          value: foundryOpenAIApiVersion
        }
        {
          name: 'AZURE_OPENAI_API_VERSION'
          value: foundryOpenAIApiVersion
        }
      ]
    }
  }
  tags: {
    'azd-service-name': 'function'
  }
}

output name string = functionApp.name
output resourceId string = functionApp.id
output defaultHostName string = functionApp.properties.defaultHostName
output principalId string = functionApp.identity.principalId
