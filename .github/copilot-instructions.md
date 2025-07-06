# Wix Studio Agency - Development Instructions

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## Project Overview

This is a multi-stack Wix Studio agency platform with Azure cloud deployment capabilities.

## Technology Stack

- **Frontend/Internal Tools**: React with Next.js (TypeScript)
- **Client Websites**: Node.js with Express (TypeScript)
- **API Services**: Node.js with Express (TypeScript)
- **Microservices**: Python with FastAPI
- **Cloud Infrastructure**: Azure (App Service, Container Apps, SQL Database, Cosmos DB)
- **Deployment**: Azure Developer CLI (azd) with GitHub Actions

## Architecture Guidelines

### Code Organization

- `packages/wix-websites/` - Node.js applications for Wix Studio client websites
- `packages/internal-tools/` - React-based admin dashboard and internal tools
- `packages/api-services/` - Backend API services for Azure and client management
- `packages/microservices/` - Python microservices for custom integrations
- `infrastructure/` - Azure Bicep templates and configuration

### Development Practices

1. **Multi-tenant Architecture**: Design all services to support multiple clients
2. **Environment Separation**: Use dev, staging, and production environments
3. **Security First**: Always use Azure Key Vault for secrets and sensitive data
4. **Cost Optimization**: Leverage free tiers and consumption-based pricing
5. **Monitoring**: Include Application Insights in all services

### Wix Integration Patterns

- Use the official Wix SDK for all Wix Studio integrations
- Implement proper OAuth flows for client authentication
- Handle webhooks asynchronously through the Python microservices
- Cache frequently accessed data using Cosmos DB

### Azure Best Practices

- Use managed identities for all Azure service authentication
- Implement proper RBAC (Role-Based Access Control)
- Use deployment slots for zero-downtime deployments
- Enable diagnostic settings for all resources

### Code Quality Standards

- TypeScript for all JavaScript/Node.js code
- Type hints for all Python code
- ESLint and Prettier for code formatting
- Jest for testing JavaScript/TypeScript
- Pytest for testing Python code

## Development Workflow

1. Make changes in the appropriate package directory
2. Test locally using `npm run dev` or individual package scripts
3. Use GitHub Actions for automated CI/CD
4. Deploy to staging first, then production

## Environment Variables

Set these in Azure Key Vault:

- `WIX_CLIENT_ID` - Wix Studio application client ID
- `WIX_ACCESS_TOKEN` - Wix Studio access token
- `WIX_REFRESH_TOKEN` - Wix Studio refresh token
- `SQL_ADMIN_PASSWORD` - SQL Database admin password

## Quick Start Commands

```bash
# Install all dependencies
npm run install:all

# Start all services in development
npm run dev

# Build all packages
npm run build

# Deploy to Azure (requires azd setup)
azd up
```

## Common Tasks

- **Adding a new client**: Update the API services and internal tools
- **Creating new integrations**: Add endpoints to microservices
- **Scaling resources**: Modify the Bicep templates in infrastructure/
- **Monitoring issues**: Check Application Insights dashboard
