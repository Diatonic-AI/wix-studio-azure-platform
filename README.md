# Wix Studio Agency Platform

**Status: GPG Verification Testing** ✅

A comprehensive multi-stack platform for managing Wix Studio client projects with Azure cloud deployment capabilities.

## 🚀 Architecture Overview

This platform provides a complete solution for a Wix Studio agency, including:

- **Client Websites** (Node.js/Express) - Host and manage Wix Studio client websites
- **Internal Tools** (React/Next.js) - Admin dashboard for project management
- **API Services** (Node.js/Express) - Backend services for Azure and client management
- **Microservices** (Python/FastAPI) - Custom integrations and data processing
- **Azure Infrastructure** - Complete cloud deployment with Bicep templates

## 🏗️ Project Structure

```
wix-studio-agency/
├── packages/
│   ├── wix-websites/          # Node.js apps for client websites
│   ├── internal-tools/        # React admin dashboard
│   ├── api-services/          # Backend API services
│   └── microservices/         # Python microservices
├── infrastructure/
│   └── bicep/                 # Azure infrastructure templates
├── .github/
│   ├── workflows/             # GitHub Actions CI/CD
│   └── copilot-instructions.md
├── azure.yaml                 # Azure Developer CLI config
└── package.json               # Root workspace configuration
```

## 🛠️ Technology Stack

### Frontend & Internal Tools
- **React 18** with Next.js 14
- **TypeScript** for type safety
- **Tailwind CSS** for styling
- **Headless UI** for components

### Backend Services
- **Node.js 18** with Express
- **TypeScript** for type safety
- **Wix SDK** for integrations
- **Azure SDK** for cloud management

### Microservices
- **Python 3.11** with FastAPI
- **Pydantic** for data validation
- **Uvicorn** for ASGI server
- **httpx** for async HTTP requests

### Cloud Infrastructure
- **Azure App Service** (Basic B1) - Node.js applications
- **Azure Static Web Apps** - React applications
- **Azure Container Apps** - Python microservices
- **Azure SQL Database** (Basic) - Structured data
- **Azure Cosmos DB** (Free tier) - Document storage
- **Azure Key Vault** - Secrets management
- **Azure Application Insights** - Monitoring
- **Azure CDN** - Content delivery

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- Python 3.11+
- Azure CLI
- Azure Developer CLI (azd)
- Git

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd AZURE_DEPLOYMENT

# Install all dependencies
npm run install:all

# Copy environment template
copy .env.example .env.local
# Edit .env.local with your actual values
```

### 2. Development
```bash
# Start all services in development mode
npm run dev

# Or start individual services:
npm run dev:web          # Wix websites (port 3000)
npm run dev:tools        # Internal tools (port 3001)
npm run dev:api          # API services (port 3002)
npm run dev:microservices # Python services (port 8000)
```

### 3. Build and Test
```bash
# Build all packages
npm run build

# Run linting
npm run lint

# Run tests
npm test
```

### 4. Azure Deployment
```bash
# Initialize Azure environment
azd auth login
azd init

# Set environment variables
azd env set AZURE_ENV_NAME dev
azd env set AZURE_LOCATION eastus

# Deploy to Azure
azd up
```

## 📦 Package Details

### Wix Websites (`packages/wix-websites/`)
Node.js Express application for hosting Wix Studio client websites.

**Key Features:**
- Wix SDK integration
- Client website hosting
- API endpoints for Wix data
- Health monitoring

**Scripts:**
- `npm run dev` - Start development server
- `npm run build` - Build TypeScript to JavaScript
- `npm start` - Start production server

### Internal Tools (`packages/internal-tools/`)
React dashboard for managing clients, projects, and deployments.

**Key Features:**
- Client project management
- Azure resource monitoring
- Deployment dashboard
- Real-time status updates

**Scripts:**
- `npm run dev` - Start Next.js development server
- `npm run build` - Build for production
- `npm start` - Start production server

### API Services (`packages/api-services/`)
Backend API for Azure management and client operations.

**Key Features:**
- Azure resource management
- Client data management
- Project deployment APIs
- Authentication & authorization

**Scripts:**
- `npm run dev` - Start development server with hot reload
- `npm run build` - Compile TypeScript
- `npm start` - Start production server

### Microservices (`packages/microservices/`)
Python FastAPI services for custom integrations and data processing.

**Key Features:**
- Wix webhook handlers
- Data processing pipelines
- Custom integrations
- Analytics processing

**Scripts:**
- `python -m uvicorn main:app --reload` - Development server
- `python main.py` - Production server

## ☁️ Azure Architecture

### Cost Optimization
The architecture is designed to stay under $250/month:

- **App Service Basic B1**: ~$55/month
- **Container Apps Consumption**: ~$30/month
- **SQL Database Basic**: ~$5/month
- **Cosmos DB Free Tier**: $0 (1000 RU/s included)
- **Key Vault Standard**: ~$3/month
- **Application Insights**: ~$10/month (pay-as-you-go)
- **CDN Standard**: ~$20/month
- **Static Web Apps**: $0 (free tier)

**Total Estimated Cost**: ~$125-150/month

### Environments
- **Development**: Local development with Azure services
- **Staging**: Dedicated Azure environment for testing
- **Production**: Production Azure environment

### Security
- Managed identities for Azure service authentication
- Key Vault for all secrets and connection strings
- HTTPS enforced on all services
- CORS configured for cross-origin requests
- Basic authentication and authorization

## 🔧 Configuration

### Environment Variables
Copy `.env.example` to `.env.local` and configure:

```bash
# Wix Studio
WIX_CLIENT_ID=your_wix_client_id
WIX_ACCESS_TOKEN=your_wix_access_token
WIX_REFRESH_TOKEN=your_wix_refresh_token

# Azure
AZURE_SUBSCRIPTION_ID=your_subscription_id
AZURE_TENANT_ID=your_tenant_id
AZURE_CLIENT_ID=your_client_id

# Database
SQL_ADMIN_PASSWORD=secure_password
```

### Azure Key Vault Secrets
The following secrets should be configured in Azure Key Vault:
- `wix-client-id`
- `wix-access-token`
- `wix-refresh-token`
- `sql-admin-password`

## 🚀 Deployment

### GitHub Actions
Automated CI/CD pipeline with:
- Code linting and testing
- Multi-environment deployment
- Staging and production workflows
- Azure authentication via service principal

### Manual Deployment
```bash
# Set environment
azd env set AZURE_ENV_NAME production
azd env set AZURE_LOCATION eastus

# Deploy infrastructure and applications
azd up --no-prompt
```

## 📊 Monitoring

### Application Insights
- Real-time performance monitoring
- Error tracking and diagnostics
- Custom telemetry and metrics
- Application maps and dependencies

### Health Checks
All services expose `/health` endpoints:
- Wix Websites: http://localhost:3000/health
- API Services: http://localhost:3002/health
- Internal Tools: http://localhost:3001
- Microservices: http://localhost:8000/health

## 🧪 Development Guidelines

### Code Quality
- TypeScript for all JavaScript/Node.js code
- Type hints for all Python code
- ESLint and Prettier for formatting
- Jest for JavaScript/TypeScript testing
- Pytest for Python testing

### Git Workflow
- `main` branch for production releases
- `develop` branch for staging deployments
- Feature branches for new development
- Pull requests required for all changes

### Adding New Features
1. Create feature branch from `develop`
2. Implement changes in appropriate package
3. Add tests and documentation
4. Submit pull request
5. Deploy to staging for testing
6. Merge to main for production

## 🆘 Troubleshooting

### Common Issues

**Module not found errors**: Run `npm run install:all` to install all dependencies

**Azure authentication**: Ensure you're logged in with `azd auth login`

**Environment variables**: Check `.env.local` file exists and has correct values

**Port conflicts**: Ensure ports 3000, 3001, 3002, 8000 are available

### Getting Help
- Check Application Insights for runtime errors
- Review GitHub Actions logs for deployment issues
- Use `azd logs` to view Azure application logs
- Check individual package README files for specific guidance

## 📄 License

MIT License - see LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
