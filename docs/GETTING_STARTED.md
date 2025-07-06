# Getting Started - Wix Studio Agency Platform

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm 9+
- Python 3.13+ with pip
- Azure CLI (for cloud deployment)
- Git

### 1. Install Dependencies
```bash
npm run install:all
```

### 2. Environment Setup
```bash
# Copy environment template
copy .env.example .env

# Edit .env file with your configuration
# - Add your Wix Studio credentials
# - Add Azure subscription details
# - Configure other service settings
```

### 3. Development Mode
```bash
# Start all services in development mode
npm run dev

# Or start individual services:
npm run dev:web        # Wix Websites (Port 3000)
npm run dev:api        # API Services (Port 3002)
npm run dev:tools      # Internal Tools (Port 3001)
npm run dev:microservices  # Python Microservices (Port 8000)
```

### 4. Build for Production
```bash
npm run build
```

### 5. Deploy to Azure
```bash
# Login to Azure
azd auth login

# Deploy infrastructure and services
azd up
```

## 📊 Service Ports

| Service | Port | Description |
|---------|------|-------------|
| Wix Websites | 3000 | Node.js client websites |
| Internal Tools | 3001 | React admin dashboard |
| API Services | 3002 | Backend API services |
| Microservices | 8000 | Python FastAPI services |

## 🔧 Development URLs

- **Wix Websites**: http://localhost:3000
- **Internal Tools**: http://localhost:3001
- **API Services**: http://localhost:3002
- **Microservices**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs

## 🛠️ VS Code Tasks

Available in Command Palette (`Ctrl+Shift+P` → "Tasks: Run Task"):

- **Install All Dependencies**
- **Start All Services**
- **Build All Packages**
- **Deploy to Azure (Development)**
- **Azure Login**

## 📁 Project Structure

```
├── packages/
│   ├── wix-websites/     # Node.js websites for clients
│   ├── internal-tools/   # React admin dashboard
│   ├── api-services/     # Backend API services
│   └── microservices/    # Python FastAPI services
├── infrastructure/       # Azure Bicep templates
├── .github/             # CI/CD workflows
└── .vscode/             # VS Code configuration
```

## 🔐 Environment Variables

Key variables to configure in `.env`:

```bash
# Wix Studio
WIX_CLIENT_ID=your_wix_client_id
WIX_ACCESS_TOKEN=your_wix_access_token
WIX_REFRESH_TOKEN=your_wix_refresh_token

# Azure
AZURE_SUBSCRIPTION_ID=your_azure_subscription_id
AZURE_TENANT_ID=your_azure_tenant_id

# Database
SQL_ADMIN_PASSWORD=your_secure_password
```

## 🔄 Next Steps

1. **Configure Wix Studio Integration**
   - Set up your Wix Studio app credentials
   - Configure OAuth flow for client authentication

2. **Set up Azure Resources**
   - Configure Azure subscription
   - Set up Key Vault for secrets
   - Configure monitoring and logging

3. **Customize Services**
   - Add your specific business logic
   - Configure client management features
   - Set up custom integrations

4. **Deploy to Production**
   - Configure production environment variables
   - Set up CI/CD pipeline
   - Configure monitoring and alerts

## 🆘 Troubleshooting

### Common Issues

**Build Errors:**
```bash
npm run build
# Check for TypeScript errors and fix them
```

**Port Conflicts:**
```bash
# Kill processes on specific ports
npx kill-port 3000 3001 3002 8000
```

**Python Dependencies:**
```bash
cd packages/microservices
pip install -r requirements.txt
```

**Azure Login Issues:**
```bash
azd auth login --check-status
azd auth login
```

## 📚 Resources

- [Wix Studio SDK Documentation](https://dev.wix.com/)
- [Azure Developer CLI](https://docs.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Next.js Documentation](https://nextjs.org/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
