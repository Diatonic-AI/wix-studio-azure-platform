// Example: Using Azure Key Vault Configuration in Your App
// ========================================================
// This shows how to use the configuration service in your actual application

import express from 'express';
import { configService } from './config';

const app = express();

// Initialize your app with proper configuration
async function initializeApp() {
  try {
    console.log('🚀 Initializing Wix Studio Agency API...');

    // Initialize configuration (automatically detects Azure vs local)
    await configService.initialize();

    // Get configuration
    const config = await configService.getConfig();
    const wixConfig = await configService.getWixConfig();

    console.log('✅ Configuration loaded:');
    console.log(`   Environment: ${config.environment}`);
    console.log(`   Azure Subscription: ${config.azure.subscriptionId.substring(0, 8)}...`);
    console.log(`   Wix Client ID: ${wixConfig.clientId.substring(0, 8)}...`);

    // Set up your Wix SDK with the configuration
    const wixClient = await initializeWixClient(wixConfig);

    // Set up routes that use the configuration
    setupRoutes(app, config, wixClient);

    // Start the server
    const port = process.env.PORT || 3002;
    app.listen(port, () => {
      console.log(`🌐 Server running on port ${port}`);
      console.log(`📊 Environment: ${config.environment}`);
      console.log(`🔐 Using ${configService.getEnvironmentSettings().isAzure ? 'Azure Key Vault' : 'local environment variables'}`);
    });

  } catch (error) {
    console.error('❌ Failed to initialize application:', error);
    process.exit(1);
  }
}

// Example: Initialize Wix SDK with configuration
async function initializeWixClient(wixConfig: any) {
  // In a real implementation, you would use the Wix SDK here
  // For now, we'll just return a mock client
  console.log('🔧 Initializing Wix SDK...');

  return {
    clientId: wixConfig.clientId,
    // Add your Wix SDK initialization here
    // const wixClient = createClient({
    //   modules: { products, collections },
    //   auth: OAuthStrategy({
    //     clientId: wixConfig.clientId,
    //     tokens: {
    //       accessToken: { value: wixConfig.accessToken },
    //       refreshToken: { value: wixConfig.refreshToken }
    //     }
    //   })
    // });
  };
}

// Example: Set up routes that use configuration
function setupRoutes(app: express.Application, config: any, wixClient: any) {
  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      environment: config.environment,
      azure: {
        subscription: config.azure.subscriptionId.substring(0, 8) + '...',
        usingKeyVault: configService.getEnvironmentSettings().isAzure
      }
    });
  });

  // Configuration info endpoint (for debugging)
  app.get('/config/info', async (req, res) => {
    const envSettings = configService.getEnvironmentSettings();

    res.json({
      environment: config.environment,
      isProduction: envSettings.isProduction,
      isDevelopment: envSettings.isDevelopment,
      isRunningInAzure: envSettings.isAzure,
      hasKeyVault: envSettings.hasKeyVault,
      configuredServices: {
        wix: !!config.wix.clientId,
        azure: !!config.azure.subscriptionId,
        database: !!config.database.connectionString
      }
    });
  });

  // Example: Refresh secrets endpoint (useful for Key Vault token rotation)
  app.post('/config/refresh', async (req, res) => {
    try {
      await configService.refreshSecrets();
      res.json({ success: true, message: 'Secrets refreshed successfully' });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Failed to refresh secrets',
        details: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });

  // Example: Wix integration endpoint using configuration
  app.get('/wix/status', async (req, res) => {
    try {
      const wixConfig = await configService.getWixConfig();

      // Here you would use the wixConfig to make actual Wix API calls
      // For demo purposes, we'll just return the configuration status
      res.json({
        success: true,
        wix: {
          clientId: wixConfig.clientId.substring(0, 8) + '...',
          hasAccessToken: !!wixConfig.accessToken,
          hasRefreshToken: !!wixConfig.refreshToken
        }
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Failed to get Wix configuration',
        details: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
}

// Start the application
if (require.main === module) {
  initializeApp();
}

export { initializeApp };
