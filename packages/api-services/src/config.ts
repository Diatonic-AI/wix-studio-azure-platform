// Azure Configuration Service
// ==========================
// This service handles configuration for both local development and Azure production
// - Local: Uses .env file
// - Azure: Uses Key Vault with managed identity

import { DefaultAzureCredential } from '@azure/identity';
import { SecretClient } from '@azure/keyvault-secrets';
import dotenv from 'dotenv';

dotenv.config();

interface WixConfig {
  clientId: string;
  accessToken: string;
  refreshToken: string;
}

interface DatabaseConfig {
  connectionString: string;
  adminPassword: string;
}

interface AppConfig {
  wix: WixConfig;
  database: DatabaseConfig;
  azure: {
    subscriptionId: string;
    tenantId: string;
    keyVaultUrl?: string | undefined;
  };
  environment: 'development' | 'staging' | 'production';
}

class ConfigurationService {
  private config: AppConfig | null = null;
  private secretClient: SecretClient | null = null;
  private isInitialized = false;

  constructor() {
    // Initialize Azure Key Vault client if running in Azure
    if (this.isRunningInAzure()) {
      const keyVaultUrl = process.env.KEY_VAULT_URL || process.env.AZURE_KEY_VAULT_URL;
      if (keyVaultUrl) {
        const credential = new DefaultAzureCredential();
        this.secretClient = new SecretClient(keyVaultUrl, credential);
        console.log('🔐 Using Azure Key Vault for secrets');
      }
    } else {
      console.log('🏠 Using local environment variables');
    }
  }

  /**
   * Initialize configuration by loading from appropriate source
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      if (this.secretClient) {
        // Running in Azure - use Key Vault
        this.config = await this.loadFromKeyVault();
      } else {
        // Running locally - use environment variables
        this.config = this.loadFromEnvironment();
      }

      this.isInitialized = true;
      console.log('✅ Configuration loaded successfully');
    } catch (error) {
      console.error('❌ Failed to load configuration:', error);
      throw new Error('Configuration initialization failed');
    }
  }

  /**
   * Get complete configuration (initialize if needed)
   */
  async getConfig(): Promise<AppConfig> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    if (!this.config) {
      throw new Error('Configuration not available');
    }

    return this.config;
  }

  /**
   * Get Wix configuration specifically
   */
  async getWixConfig(): Promise<WixConfig> {
    const config = await this.getConfig();
    return config.wix;
  }

  /**
   * Check if running in Azure (vs local development)
   */
  private isRunningInAzure(): boolean {
    // Check for Azure-specific environment variables
    return !!(
      process.env.WEBSITE_SITE_NAME || // App Service
      process.env.CONTAINER_APP_NAME || // Container Apps
      process.env.AZURE_CLIENT_ID || // Managed Identity
      process.env.MSI_ENDPOINT // Managed Identity endpoint
    );
  }

  /**
   * Load configuration from Azure Key Vault
   */
  private async loadFromKeyVault(): Promise<AppConfig> {
    if (!this.secretClient) {
      throw new Error('Key Vault client not initialized');
    }

    console.log('🔐 Loading secrets from Azure Key Vault...');

    try {
      // Load secrets from Key Vault
      const [wixClientId, wixAccessToken, wixRefreshToken, sqlPassword] = await Promise.all([
        this.getSecret('wix-client-id'),
        this.getSecret('wix-access-token'),
        this.getSecret('wix-refresh-token'),
        this.getSecret('sql-admin-password')
      ]);

      return {
        wix: {
          clientId: wixClientId,
          accessToken: wixAccessToken,
          refreshToken: wixRefreshToken
        },
        database: {
          connectionString: this.buildConnectionString(sqlPassword),
          adminPassword: sqlPassword
        },
        azure: {
          subscriptionId: process.env.AZURE_SUBSCRIPTION_ID || '',
          tenantId: process.env.AZURE_TENANT_ID || '',
          keyVaultUrl: process.env.KEY_VAULT_URL || process.env.AZURE_KEY_VAULT_URL
        },
        environment: (process.env.NODE_ENV as any) || 'production'
      };
    } catch (error) {
      console.error('❌ Error loading from Key Vault:', error);
      throw error;
    }
  }

  /**
   * Load configuration from environment variables (local development)
   */
  private loadFromEnvironment(): AppConfig {
    console.log('🏠 Loading configuration from environment variables...');

    // Validate required environment variables
    const requiredVars = [
      'WIX_CLIENT_ID',
      'WIX_ACCESS_TOKEN',
      'WIX_REFRESH_TOKEN',
      'AZURE_SUBSCRIPTION_ID'
    ];

    const missing = requiredVars.filter(varName => !process.env[varName]);
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }

    return {
      wix: {
        clientId: process.env.WIX_CLIENT_ID!,
        accessToken: process.env.WIX_ACCESS_TOKEN!,
        refreshToken: process.env.WIX_REFRESH_TOKEN!
      },
      database: {
        connectionString: process.env.DATABASE_CONNECTION_STRING || '',
        adminPassword: process.env.SQL_ADMIN_PASSWORD || ''
      },
      azure: {
        subscriptionId: process.env.AZURE_SUBSCRIPTION_ID!,
        tenantId: process.env.AZURE_TENANT_ID || '',
        keyVaultUrl: process.env.KEY_VAULT_URL
      },
      environment: (process.env.NODE_ENV as any) || 'development'
    };
  }

  /**
   * Get a secret from Key Vault
   */
  private async getSecret(secretName: string): Promise<string> {
    if (!this.secretClient) {
      throw new Error('Key Vault client not available');
    }

    try {
      const secret = await this.secretClient.getSecret(secretName);
      if (!secret.value) {
        throw new Error(`Secret '${secretName}' has no value`);
      }
      return secret.value;
    } catch (error) {
      console.error(`❌ Failed to get secret '${secretName}':`, error);
      throw error;
    }
  }

  /**
   * Build database connection string with password from Key Vault
   */
  private buildConnectionString(password: string): string {
    const serverName = process.env.SQL_SERVER_NAME || 'localhost';
    const databaseName = process.env.SQL_DATABASE_NAME || 'wixagency';
    const username = process.env.SQL_ADMIN_USERNAME || 'azureuser';

    return `Server=tcp:${serverName}.database.windows.net,1433;Initial Catalog=${databaseName};Persist Security Info=False;User ID=${username};Password=${password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;`;
  }

  /**
   * Refresh secrets from Key Vault (useful for token rotation)
   */
  async refreshSecrets(): Promise<void> {
    if (!this.isRunningInAzure() || !this.secretClient) {
      console.log('🏠 Secret refresh not applicable in local development');
      return;
    }

    console.log('🔄 Refreshing secrets from Key Vault...');
    this.isInitialized = false;
    await this.initialize();
  }

  /**
   * Get environment-specific settings
   */
  getEnvironmentSettings() {
    return {
      isProduction: this.config?.environment === 'production',
      isDevelopment: this.config?.environment === 'development',
      isAzure: this.isRunningInAzure(),
      hasKeyVault: !!this.secretClient
    };
  }
}

// Export singleton instance
export const configService = new ConfigurationService();

// Export types for use in other modules
export type { AppConfig, DatabaseConfig, WixConfig };

// Example usage in your application:
//
// import { configService } from './config';
//
// async function initializeApp() {
//   try {
//     await configService.initialize();
//     const wixConfig = await configService.getWixConfig();
//
//     // Use wixConfig.clientId, wixConfig.accessToken, etc.
//     console.log('Wix Client ID:', wixConfig.clientId);
//   } catch (error) {
//     console.error('Failed to initialize app:', error);
//     process.exit(1);
//   }
// }
