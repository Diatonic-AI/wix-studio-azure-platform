# GitHub-Only DevOps Guide

**Complete guide for GitHub-only CI/CD with Azure deployment - no Azure DevOps needed!**

## 🎯 Why GitHub-Only DevOps?

### ✅ Advantages

- **Single source of truth** - Code, issues, deployments all in GitHub
- **Simpler setup** - No need to sync between GitHub and Azure DevOps
- **Better integration** - Native GitHub features (Issues, PRs, Actions)
- **Cost effective** - GitHub Actions included with repositories
- **Modern workflow** - Industry standard approach
- **Easier maintenance** - One platform to manage

### 🚫 What We're NOT Using

- ❌ Azure DevOps Pipelines
- ❌ Azure Container Registry (using GitHub Container Registry)
- ❌ Complex multi-platform orchestration
- ❌ Separate CI/CD tooling

---

## 🔐 GitHub Actions Authentication to Azure

### Method 1: OpenID Connect (OIDC) - RECOMMENDED

**Why OIDC is Better:**

- ✅ No secrets to manage or rotate
- ✅ More secure than client secrets
- ✅ Automatic token management
- ✅ Granular permissions per repository

**Setup Steps:**

1. **Create Azure App Registration:**

   ```bash
   az ad app create --display-name "wix-studio-github-oidc"
   ```

2. **Create Service Principal:**

   ```bash
   # Get the app ID from step 1
   APP_ID=$(az ad app list --display-name "wix-studio-github-oidc" --query "[0].appId" -o tsv)
   
   # Create service principal
   az ad sp create --id $APP_ID
   
   # Assign contributor role
   az role assignment create \
     --role "Contributor" \
     --assignee $APP_ID \
     --scope "/subscriptions/$(az account show --query id -o tsv)"
   ```

3. **Configure OIDC Federated Credentials:**

   ```bash
   # For main branch
   az ad app federated-credential create \
     --id $APP_ID \
     --parameters '{
       "name": "github-main",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:Diatonic-AI/wix-studio-azure-platform:ref:refs/heads/main",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   
   # For pull requests
   az ad app federated-credential create \
     --id $APP_ID \
     --parameters '{
       "name": "github-pr",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:Diatonic-AI/wix-studio-azure-platform:pull_request",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   ```

### Method 2: Service Principal (Fallback)

**Only use if OIDC doesn't work for your scenario.**

```bash
az ad sp create-for-rbac \
  --name "wix-studio-platform" \
  --role "Contributor" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)"
```

---

## 📝 Required GitHub Secrets

### For OIDC Authentication (Recommended)

```yaml
# Required GitHub Repository Secrets:
AZURE_CLIENT_ID: "12345678-1234-1234-1234-123456789012"  # App registration client ID
AZURE_TENANT_ID: "11111111-2222-3333-4444-555555555555"  # Your Azure AD tenant ID
AZURE_SUBSCRIPTION_ID: "87654321-4321-4321-4321-210987654321"  # Your subscription ID
```

### For Service Principal (Fallback)

```yaml
# Additional secret needed:
AZURE_CLIENT_SECRET: "your-client-secret-here"  # Only if not using OIDC
```

### Application Secrets

```yaml
# Wix Studio API
WIX_CLIENT_ID: "your-wix-app-client-id"
WIX_ACCESS_TOKEN: "your-wix-access-token"
WIX_REFRESH_TOKEN: "your-wix-refresh-token"

# Database
SQL_ADMIN_PASSWORD: "your-secure-database-password"

# Optional: External Services
SONAR_TOKEN: "your-sonarcloud-token"  # For code quality
OPENAI_API_KEY: "your-openai-key"     # For AI code review
SLACK_WEBHOOK_URL: "your-slack-webhook"  # For notifications
```

---

## 🔄 GitHub Actions Workflow Architecture

### Main Workflows

1. **CI/CD Pipeline** (`.github/workflows/azure-deploy.yml`)
   - Triggered on push to `main`
   - Builds all services
   - Runs tests and security scans
   - Deploys to Azure

2. **AI Code Review** (`.github/workflows/ai-code-review.yml`)
   - Triggered on pull requests
   - AI-powered code analysis
   - Automated quality gates

3. **Security Scanning** (Integrated in main pipeline)
   - Dependency vulnerability scanning
   - Secret scanning
   - Code quality analysis

### GitHub Container Registry

**Why GitHub Container Registry over Azure Container Registry:**

- ✅ Native integration with GitHub Actions
- ✅ No additional Azure resource costs
- ✅ Automatic cleanup policies
- ✅ Fine-grained access control

```yaml
# Container images are pushed to:
ghcr.io/diatonic-ai/wix-studio-azure-platform/microservices:latest
ghcr.io/diatonic-ai/wix-studio-azure-platform/api-services:latest
```

---

## 🏗️ Simplified Azure Resources

### Core Infrastructure (Bicep Templates)

**What gets deployed to Azure:**

1. **Resource Group**
   - Contains all resources
   - Environment-specific naming

2. **App Service Plan** (Basic B1)
   - Hosts Node.js applications
   - Cost: ~$55/month

3. **App Services**
   - Wix websites service
   - API services
   - Auto-deployment from GitHub

4. **Container Apps Environment**
   - Hosts Python microservices
   - Consumption-based pricing

5. **Container Apps**
   - Python FastAPI services
   - Auto-scaling based on demand

6. **Azure SQL Database** (Basic)
   - Client and project data
   - Cost: ~$5/month

7. **Cosmos DB** (Free tier)
   - Document storage
   - 1000 RU/s included free

8. **Key Vault**
   - Secure secret storage
   - Cost: ~$3/month

9. **Application Insights**
   - Monitoring and analytics
   - Pay-as-you-go pricing

### Managed Identities

**All Azure services use managed identities - no additional secrets needed!**

- App Services → Key Vault (automatic)
- Container Apps → Key Vault (automatic)
- Container Apps → Cosmos DB (automatic)
- Container Apps → SQL Database (automatic)

---

## ⚡ Quick Setup Guide

### 1. Set up OIDC Authentication

```bash
# Login to Azure
az login

# Run the setup script
./scripts/setup-azure-oidc.ps1 -RepoName "Diatonic-AI/wix-studio-azure-platform"
```

### 2. Configure GitHub Secrets

```bash
# Run the GitHub secrets setup
./scripts/setup-github-secrets.ps1
```

### 3. Deploy Infrastructure

```bash
# Push to main branch triggers deployment
git push origin main
```

### 4. Monitor Deployment

```bash
# Check GitHub Actions tab in repository
# Monitor Application Insights for runtime metrics
```

---

## 🔍 How to Get Your Azure IDs

### Subscription ID

```bash
az account show --query id -o tsv
```

### Tenant ID

```bash
az account show --query tenantId -o tsv
```

### Client ID (after app registration)

```bash
az ad app list --display-name "wix-studio-github-oidc" --query "[0].appId" -o tsv
```

---

## 🎯 Wix Studio Credentials

### Get Wix API Credentials

1. **Create Wix Studio App**
   - Go to [Wix Developers](https://dev.wix.com/)
   - Create new app
   - Note the Client ID

2. **OAuth Setup**
   - Configure OAuth settings
   - Get authorization from clients
   - Obtain access and refresh tokens

3. **Required Scopes**
   - `read:sites` - Read site information
   - `read:content` - Access site content
   - `manage:sites` - Manage sites (if needed)

---

## 🛡️ Security Best Practices

### GitHub Repository Security

1. **Branch Protection Rules**
   - Require PR reviews
   - Require status checks
   - No direct pushes to main

2. **Secret Scanning**
   - Automatic secret detection
   - Block commits with secrets
   - Alert on exposed secrets

3. **Dependency Scanning**
   - Dependabot alerts
   - Automatic security updates
   - License compliance checking

### Azure Security

1. **Managed Identities**
   - No secrets in application code
   - Automatic credential rotation
   - Fine-grained permissions

2. **Key Vault Integration**
   - All secrets stored securely
   - Audit logging enabled
   - Access policies enforced

3. **Network Security**
   - HTTPS enforced everywhere
   - Private endpoints where possible
   - Firewall rules configured

---

## 🚀 Deployment Environments

### Environment Strategy

1. **Development**
   - Local development with Azure services
   - Feature branch deployments to review apps

2. **Staging**
   - Triggered by PR to main
   - Full integration testing
   - Performance testing

3. **Production**
   - Triggered by merge to main
   - Blue-green deployment
   - Automatic rollback on failure

### GitHub Environments

```yaml
environments:
  development:
    protection_rules: []
  staging:
    protection_rules:
      - required_reviewers: 1
  production:
    protection_rules:
      - required_reviewers: 2
      - wait_timer: 5  # 5 minute delay
```

---

## 📊 Cost Optimization

### GitHub Actions Minutes

- **Free tier**: 2,000 minutes/month
- **Expected usage**: ~500 minutes/month
- **Cost**: $0 (within free tier)

### Azure Resources

- **App Service Basic B1**: $55/month
- **Container Apps**: $20-30/month (consumption)
- **SQL Database Basic**: $5/month
- **Cosmos DB**: $0 (free tier)
- **Key Vault**: $3/month
- **Application Insights**: $10/month
- **Total**: ~$95-105/month

### Container Registry

- **GitHub Container Registry**: Free for public repositories
- **Azure Container Registry**: $5/month + bandwidth
- **Savings**: $5/month by using GitHub

---

## 🆘 Troubleshooting

### Common GitHub Actions Issues

**"OIDC token validation failed"**

- Check federated credential configuration
- Verify repository name matches exactly
- Ensure AZURE_CLIENT_ID is correct

**"Resource group not found"**

- Check AZURE_SUBSCRIPTION_ID
- Verify service principal has correct permissions
- Check resource group naming in Bicep templates

**"Container image not found"**

- Verify GitHub Container Registry permissions
- Check image tags in workflow
- Ensure container build succeeded

### Wix API Issues

**"Access token expired"**

- Use refresh token to get new access token
- Implement automatic token refresh
- Check token expiration handling

**"Insufficient permissions"**

- Verify OAuth scopes
- Check Wix app permissions
- Ensure client has authorized app

---

## 📚 Additional Resources

- [GitHub Actions Azure Authentication](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure OIDC with GitHub](https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Wix Studio API](https://dev.wix.com/api/rest/getting-started/introduction)

---

## ✅ Setup Checklist

### Initial Setup

- [ ] Create Azure app registration
- [ ] Configure OIDC federated credentials
- [ ] Set GitHub repository secrets
- [ ] Create Wix Studio app
- [ ] Configure OAuth for Wix

### First Deployment

- [ ] Push code to main branch
- [ ] Monitor GitHub Actions workflow
- [ ] Verify Azure resources created
- [ ] Test application endpoints
- [ ] Check Application Insights data

### Production Ready

- [ ] Configure branch protection rules
- [ ] Set up monitoring alerts
- [ ] Configure backup strategies
- [ ] Document runbook procedures
- [ ] Train team on GitHub Actions workflows
