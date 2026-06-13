param storageAccountName string
param appInsightsName string
param principalId string


var storageBlobDataOwnerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var storageQueueDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
var storageTableDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
var monitoringMetricsPublisherRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource storageBlobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, storageBlobDataOwnerRoleDefinitionId)
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: storageBlobDataOwnerRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, storageBlobDataContributorRoleDefinitionId)
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource storageQueueDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, storageQueueDataContributorRoleDefinitionId)
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: storageQueueDataContributorRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource storageTableDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, storageTableDataContributorRoleDefinitionId)
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: storageTableDataContributorRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource monitoringMetricsPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsights.id, principalId, monitoringMetricsPublisherRoleDefinitionId)
  scope: appInsights
  properties: {
    principalId: principalId
    roleDefinitionId: monitoringMetricsPublisherRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}
