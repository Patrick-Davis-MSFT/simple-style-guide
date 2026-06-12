targetScope = 'resourceGroup'

param foundryAccountName string
param principalId string
param foundryRoleDefinitionGuid string

var foundryRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryRoleDefinitionGuid)

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: foundryAccountName
}

resource foundryAccessRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, principalId, foundryRoleDefinitionId)
  scope: foundryAccount
  properties: {
    principalId: principalId
    roleDefinitionId: foundryRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}
