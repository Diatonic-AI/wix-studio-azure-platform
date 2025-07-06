// Main Bicep template for Wix Studio Agency Azure infrastructure
targetScope = 'resourceGroup'

@description('The location where all resources will be deployed')
param location string = resourceGroup().location

@description('The name of the environment (dev, staging, prod)')
param environmentName string

@description('The base name for all resources')
param resourceBaseName string = 'wixagency'

@description('The resource token for unique naming')
param resourceToken string = uniqueString(resourceGroup().id)

// Variables
var resourceName = '${resourceBaseName}-${environmentName}-${resourceToken}'

// App Service Plan for Node.js applications
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourceName}-plan'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  properties: {
    reserved: false
  }
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'app-service-plan'
  }
}

// App Service for Wix Websites (Node.js)
resource wixWebsitesApp 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourceName}-websites'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      nodeVersion: '18-lts'
      appSettings: [
        {
          name: 'NODE_ENV'
          value: environmentName
        }
        {
          name: 'WIX_CLIENT_ID'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=wix-client-id)'
        }
        {
          name: 'WIX_ACCESS_TOKEN'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=wix-access-token)'
        }
      ]
      cors: {
        allowedOrigins: ['*']
        supportCredentials: false
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'wix-websites'
  }
}

// App Service for API Services (Node.js)
resource apiServicesApp 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourceName}-api'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      nodeVersion: '18-lts'
      appSettings: [
        {
          name: 'NODE_ENV'
          value: environmentName
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
      ]
      cors: {
        allowedOrigins: ['*']
        supportCredentials: false
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'api-services'
  }
}

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${resourceName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  tags: {
    'azd-env-name': environmentName
  }
}

@description('GitHub container registry image for microservices')
param microservicesImage string = 'ghcr.io/diatonic-ai/wix-studio-azure-platform/microservices:latest'

@description('GitHub Personal Access Token for container registry access')
@secure()
param githubToken string = ''

// Container App for Python Microservices
resource microservicesContainer 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${resourceName}-microservices'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['*']
          allowedHeaders: ['*']
        }
      }
      registries: !empty(githubToken) ? [
        {
          server: 'ghcr.io'
          username: 'diatonic-ai'
          passwordSecretRef: 'github-registry-password'
        }
      ] : []
      secrets: !empty(githubToken) ? [
        {
          name: 'github-registry-password'
          value: githubToken
        }
      ] : []
    }
    template: {
      containers: [
        {
          name: 'microservices'
          image: microservicesImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'PORT'
              value: '8000'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'microservices'
  }
}

// User Assigned Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${resourceName}-identity'
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${resourceName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: {
    'azd-env-name': environmentName
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourceName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
  tags: {
    'azd-env-name': environmentName
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${replace(resourceName, '-', '')}kv'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: managedIdentity.properties.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
    enabledForTemplateDeployment: true
  }
  tags: {
    'azd-env-name': environmentName
  }
}

// SQL Database (Basic tier)
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: '${resourceName}-sql'
  location: location
  properties: {
    administratorLogin: 'adminuser'
    administratorLoginPassword: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=sql-admin-password)'
  }
  tags: {
    'azd-env-name': environmentName
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'wixagency'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  tags: {
    'azd-env-name': environmentName
  }
}

// Cosmos DB (Free tier)
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-09-15' = {
  name: '${replace(resourceName, '-', '')}-cosmos'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
  tags: {
    'azd-env-name': environmentName
  }
}

// CDN Profile
resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: '${resourceName}-cdn'
  location: 'Global'
  sku: {
    name: 'Standard_Microsoft'
  }
  tags: {
    'azd-env-name': environmentName
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output WIX_WEBSITES_URL string = 'https://${wixWebsitesApp.properties.defaultHostName}'
output API_SERVICES_URL string = 'https://${apiServicesApp.properties.defaultHostName}'
output MICROSERVICES_URL string = 'https://${microservicesContainer.properties.configuration.ingress.fqdn}'
output CONTAINER_REGISTRY_SERVER string = 'ghcr.io'
output KEY_VAULT_NAME string = keyVault.name
output APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = applicationInsights.properties.InstrumentationKey
output MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.properties.clientId
