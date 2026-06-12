targetScope = 'resourceGroup'

@description('The azd environment name. Must be set from AZURE_ENV_NAME.')
param environmentName string

@description('The Azure region used for all resources. Must be set from AZURE_LOCATION.')
param location string

@description('A short lowercase prefix used in resource names, set from PREFIX.')
@minLength(2)
@maxLength(8)
param prefix string

@description('Existing VNet resource ID provided at deploy-time from VNET_RESOURCE_ID.')
param vnetResourceId string


@description('Existing Azure AI Foundry project endpoint from AZURE_EXISTING_AIPROJECT_ENDPOINT.')
param foundryProjectEndpoint string

@description('Existing Azure AI Foundry agent id in name:version format from AZURE_EXISTING_AGENT_ID.')
param foundryAgentId string

@description('Existing Azure AI Foundry project resource id from AZURE_EXISTING_AIPROJECT_RESOURCE_ID.')
param foundryProjectResourceId string

@description('Existing Azure AI Foundry account resource id from AZURE_EXISTING_RESOURCE_ID.')
var normalizedproject = toLower(foundryProjectResourceId)
var projparts = split(normalizedproject, '/')
var accountsIndex = indexOf(projparts, 'accounts')
var foundryResourceId = accountsIndex == -1 ? '' : '${join(take(projparts, accountsIndex + 2), '/')}'

@description('Optional Azure AI Foundry agent name from AZURE_FOUNDRY_AGENT_NAME. Can be used instead of AZURE_EXISTING_AGENT_ID.')
param foundryAgentName string = ''

@description('Optional Azure AI Foundry agent version from AZURE_FOUNDRY_AGENT_VERSION. Can be used instead of AZURE_EXISTING_AGENT_ID.')
param foundryAgentVersion string = ''

@description('Optional role definition GUID to assign at Foundry account scope (for example Cognitive Services OpenAI User).')
param foundryRoleDefinitionGuid string = ''

@description('OpenAI API version for Foundry Azure OpenAI client initialization (for example 2025-03-01-preview).')
param foundryOpenAIApiVersion string = ''

@description('OpenAI API version from AZURE_OPENAI_API_VERSION. Preferred over OPENAI_API_VERSION when set.')
param azureOpenAIApiVersion string = ''

var resolvedOpenAIApiVersion = empty(azureOpenAIApiVersion) ? foundryOpenAIApiVersion : azureOpenAIApiVersion

var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)
var normalizedPrefix = toLower(prefix)

var storageAccountName = toLower('azst${normalizedPrefix}${substring(resourceToken, 0, 10)}')
var workspaceName = 'azlaw${normalizedPrefix}${substring(resourceToken, 0, 8)}'
var appInsightsName = 'azappi${normalizedPrefix}${substring(resourceToken, 0, 8)}'
var functionPlanName = 'azasp${normalizedPrefix}${substring(resourceToken, 0, 8)}'
var functionAppName = 'azfunc${normalizedPrefix}${substring(resourceToken, 0, 8)}'
var webAppName = 'azweb${normalizedPrefix}${substring(resourceToken, 0, 8)}'

var vnetParts = split(vnetResourceId, '/')
var vnetSubscriptionId = vnetParts[2]
var vnetResourceGroup = vnetParts[4]
var vnetName = vnetParts[8]

var foundrySubscriptionId = empty(foundryResourceId) ? '' : split(foundryResourceId, '/')[2]
var foundryResourceGroup = empty(foundryResourceId) ? '' : split(foundryResourceId, '/')[4]
var foundryAccountName = empty(foundryResourceId) ? '' : split(foundryResourceId, '/')[8]

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  scope: resourceGroup(vnetSubscriptionId, vnetResourceGroup)
  name: vnetName
}

module logAnalytics './modules/logAnalytics.bicep' = {
  name: 'logAnalyticsDeployment'
  params: {
    name: workspaceName
    location: location
  }
}

module appInsights './modules/appInsights.bicep' = {
  name: 'appInsightsDeployment'
  params: {
    name: appInsightsName
    location: location
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    name: storageAccountName
    location: location
  }
}

module functionPlan './modules/functionPlan.bicep' = {
  name: 'functionPlanDeployment'
  params: {
    name: functionPlanName
    location: location
  }
}

module functionApp './modules/functionApp.bicep' = {
  name: 'functionAppDeployment'
  params: {
    name: functionAppName
    location: location
    appServicePlanId: functionPlan.outputs.resourceId
    appInsightsConnectionString: appInsights.outputs.connectionString
    storageAccountName: storage.outputs.name
    vnetResourceId: existingVnet.id
    webAppHostname: webApp.outputs.defaultHostname
    foundryProjectEndpoint: foundryProjectEndpoint
    foundryAgentId: foundryAgentId
    foundryAgentName: foundryAgentName
    foundryAgentVersion: foundryAgentVersion
    foundryProjectResourceId: foundryProjectResourceId
    foundryResourceId: foundryResourceId
    foundryOpenAIApiVersion: resolvedOpenAIApiVersion
  }
}

module webApp './modules/staticWebApp.bicep' = {
  name: 'webAppDeployment'
  params: {
    name: webAppName
    location: location
    appServicePlanId: functionPlan.outputs.resourceId
  }
}

module functionDiagnostics './modules/functionDiagnostics.bicep' = {
  name: 'functionDiagnosticsDeployment'
  params: {
    functionAppName: functionApp.outputs.name
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

module functionRoleAssignments './modules/functionRoleAssignments.bicep' = {
  name: 'functionRoleAssignmentsDeployment'
  params: {
    storageAccountName: storage.outputs.name
    appInsightsName: appInsights.outputs.name
    principalId: functionApp.outputs.principalId
  }
}

module foundryRoleAssignment './modules/foundryRoleAssignment.bicep' = if (!empty(foundryResourceId) && !empty(foundryRoleDefinitionGuid)) {
  name: 'foundryRoleAssignmentDeployment'
  scope: resourceGroup(foundrySubscriptionId, foundryResourceGroup)
  params: {
    foundryAccountName: foundryAccountName
    principalId: functionApp.outputs.principalId
    foundryRoleDefinitionGuid: foundryRoleDefinitionGuid
  }
}

output RESOURCE_GROUP_ID string = resourceGroup().id
output AZURE_FUNCTION_APP_NAME string = functionApp.outputs.name
output FUNCTION_APP_NAME string = functionApp.outputs.name
output AZURE_WEB_APP_NAME string = webApp.outputs.name
output WEB_APP_NAME string = webApp.outputs.name
output AZURE_STATIC_WEB_APP_NAME string = webApp.outputs.name
output STATIC_WEB_APP_NAME string = webApp.outputs.name
output AZURE_STORAGE_ACCOUNT_NAME string = storage.outputs.name
output FUNCTION_API_URL string = 'https://${functionApp.outputs.defaultHostName}/api/style-check'
output OFFICE_ADDIN_TASKPANE_URL string = 'https://${webApp.outputs.defaultHostname}'
output VNET_RESOURCE_ID_ECHO string = existingVnet.id
output AZURE_EXISTING_AIPROJECT_ENDPOINT string = foundryProjectEndpoint
