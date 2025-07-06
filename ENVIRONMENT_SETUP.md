# 🔐 Complete Environment Variables & Azure Secrets Setup

## Quick Summary

Your Azure infrastructure already includes **Key Vault** with **managed identity** for secure secret management. Here's how to configure it:

### 🏠 Local Development
```bash
# 1. Copy environment template
copy .env.example .env

# 2. Edit .env with your values
WIX_CLIENT_ID=your_actual_wix_client_id
WIX_ACCESS_TOKEN=your_actual_wix_access_token
# ... etc
```

### ☁️ Azure Production
```bash
# 1. Deploy infrastructure
azd up

# 2. Add secrets to Key Vault
./scripts/setup-secrets.ps1

# 3. Secrets are automatically available as environment variables
```

## 🎯 How It Works

### Architecture Flow

```
Local Development:
.env file → process.env.WIX_CLIENT_ID

Azure Production:
Key Vault Secret (wix-client-id) → App Service Environment Variable (WIX_CLIENT_ID) → process.env.WIX_CLIENT_ID
```

### Your Code Stays the Same!
```typescript
// This works in both local and Azure:
const wixClientId = process.env.WIX_CLIENT_ID;
const wixAccessToken = process.env.WIX_ACCESS_TOKEN;
```

## 📋 Step-by-Step Setup

### Step 1: Configure Local Development

1. **Copy environment template:**
   ```bash
   copy .env.example .env
   ```

2. **Get your Wix Studio credentials:**
   - Go to [Wix Developers](https://dev.wix.com/)
   - Create or access your app
   - Copy: Client ID, Access Token, Refresh Token

3. **Edit `.env` file:**
   ```bash
   # Wix Studio Configuration
   WIX_CLIENT_ID=your_actual_client_id_here
   WIX_ACCESS_TOKEN=your_actual_access_token_here
   WIX_REFRESH_TOKEN=your_actual_refresh_token_here

   # Azure Configuration
   AZURE_SUBSCRIPTION_ID=your_azure_subscription_id
   AZURE_TENANT_ID=your_azure_tenant_id

   # Database Configuration
   SQL_ADMIN_PASSWORD=YourStrongPassword123!
   ```

### Step 2: Deploy Azure Infrastructure

1. **Login to Azure:**
   ```bash
   azd auth login
   ```

2. **Deploy infrastructure:**
   ```bash
   azd up
   ```

   This creates:
   - ✅ Key Vault with your project name
   - ✅ App Services configured to read from Key Vault
   - ✅ Managed Identity with Key Vault access
   - ✅ All the infrastructure you need

### Step 3: Add Secrets to Key Vault

**Option A: Use the PowerShell Script (Recommended)**
```bash
./scripts/setup-secrets.ps1
```
This script will:
- Detect your Key Vault automatically
- Prompt for each secret value
- Add them securely to Key Vault

**Option B: Manual Azure CLI**
```bash
# Get your Key Vault name from deployment output
azd env get-values | findstr KEY_VAULT_NAME

# Add secrets manually
az keyvault secret set --vault-name "your-keyvault-name" --name "wix-client-id" --value "your_wix_client_id"
az keyvault secret set --vault-name "your-keyvault-name" --name "wix-access-token" --value "your_wix_access_token"
az keyvault secret set --vault-name "your-keyvault-name" --name "wix-refresh-token" --value "your_wix_refresh_token"
az keyvault secret set --vault-name "your-keyvault-name" --name "sql-admin-password" --value "YourStrongPassword123!"
```

### Step 4: Restart Services (Important!)

After adding secrets, restart your Azure services:
```bash
# Get your resource group and app names
azd env get-values

# Restart App Services to pick up new secrets
az webapp restart --name "your-websites-app" --resource-group "your-resource-group"
az webapp restart --name "your-api-app" --resource-group "your-resource-group"

# Restart Container Apps
az containerapp revision restart --name "your-microservices-app" --resource-group "your-resource-group"
```

## 🔧 Advanced Configuration

### Using the Configuration Service

I've created an advanced configuration service for you in `packages/api-services/src/config.ts`. Here's how to use it:

```typescript
import { configService } from './config';

async function myApp() {
  // Initialize (automatically detects Azure vs local)
  await configService.initialize();

  // Get Wix configuration
  const wixConfig = await configService.getWixConfig();

  // Use in your code
  const wixClient = createClient({
    clientId: wixConfig.clientId,
    accessToken: wixConfig.accessToken
  });
}
```

### Environment-Specific Secrets

You can create environment-specific secrets:

```bicep
// In your Bicep template
{
  name: 'WIX_CLIENT_ID'
  value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=wix-client-id-${environmentName})'
}
```

Then add secrets like:
- `wix-client-id-dev`
- `wix-client-id-staging`
- `wix-client-id-prod`

## 🔒 Security Features

### ✅ What's Already Secured

1. **No Secrets in Code**: All secrets are in Key Vault or environment variables
2. **Managed Identity**: No passwords needed for Azure authentication
3. **RBAC**: Fine-grained access control to Key Vault
4. **Audit Logging**: All Key Vault access is logged
5. **Encryption**: Secrets encrypted at rest and in transit

### 🛡️ Best Practices Implemented

- **Least Privilege**: Services only have access to secrets they need
- **Automatic Rotation**: Azure handles credential rotation
- **Network Security**: Private networking between services
- **Environment Isolation**: Separate secrets for dev/staging/prod

## 🔍 Troubleshooting

### Check Key Vault Access
```bash
# Verify Key Vault exists
az keyvault show --name "your-keyvault-name"

# Test secret access
az keyvault secret show --vault-name "your-keyvault-name" --name "wix-client-id"
```

### Check App Service Configuration
```bash
# View app settings (secrets show as Key Vault references)
az webapp config appsettings list --name "your-app-name" --resource-group "your-rg"

# Check application logs
az webapp log tail --name "your-app-name" --resource-group "your-rg"
```

### Common Issues

1. **"Secret not found"**: Make sure secret name matches exactly (case-sensitive)
2. **"Access denied"**: Managed identity needs Key Vault access permissions
3. **"App not updating"**: Restart the App Service after adding secrets

## 📊 Secret Name Mapping

| Environment Variable | Key Vault Secret Name | Description |
|---------------------|----------------------|-------------|
| `WIX_CLIENT_ID` | `wix-client-id` | Wix Studio OAuth Client ID |
| `WIX_ACCESS_TOKEN` | `wix-access-token` | Wix Studio API Access Token |
| `WIX_REFRESH_TOKEN` | `wix-refresh-token` | Wix Studio OAuth Refresh Token |
| `SQL_ADMIN_PASSWORD` | `sql-admin-password` | SQL Database Admin Password |
| `NEXTAUTH_SECRET` | `nextauth-secret` | NextAuth.js Secret Key |

## 🚀 You're All Set!

Your environment is now configured for enterprise-grade security:

✅ **Local Development**: Uses `.env` file
✅ **Azure Production**: Uses Key Vault with managed identity
✅ **Same Code**: Works in both environments without changes
✅ **Secure**: No secrets in code or configuration files
✅ **Auditable**: All secret access is logged
✅ **Scalable**: Easy to add new secrets and environments
