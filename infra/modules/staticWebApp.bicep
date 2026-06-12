param name string
param location string
param appServicePlanId string

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|22-lts'
      appCommandLine: 'npm start'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: true
    }
  }
  tags: {
    'azd-service-name': 'app-ui'
  }
}

output name string = webApp.name
output defaultHostname string = webApp.properties.defaultHostName
