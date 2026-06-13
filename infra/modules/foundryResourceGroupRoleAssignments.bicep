targetScope = 'resourceGroup'

param principalId string

var cognitiveServicesUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
var openAIUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
var foundryDevRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '64702f94-c441-49e6-a78b-ef80e0188fee')

resource cognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, cognitiveServicesUserRoleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: cognitiveServicesUserRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource openAIUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, openAIUserRoleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: openAIUserRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource foundryDev 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, foundryDevRoleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: foundryDevRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}
