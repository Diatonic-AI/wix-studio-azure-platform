# AI-Powered CI/CD Setup Script
# This script sets up the complete AI-powered CI/CD pipeline for the Wix Platform

[CmdletBinding()]
param(
    [string]$RepositoryUrl = "",
    [string]$AzureSubscriptionId = "",
    [string]$AzureResourceGroup = "",
    [string]$GitHubToken = "",
    [switch]$SkipAzureSetup = $false,
    [switch]$SkipGitHubSetup = $false
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    switch ($Color) {
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Blue" { Write-Host $Message -ForegroundColor Blue }
        "Cyan" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n🔄 $Message" "Blue"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✅ $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠️  $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "❌ $Message" "Red"
}

# Check prerequisites
function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $missing = @()
    
    # Check Azure CLI
    try {
        $azVersion = az --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Azure CLI is installed"
        } else {
            $missing += "Azure CLI"
        }
    } catch {
        $missing += "Azure CLI"
    }
    
    # Check GitHub CLI
    try {
        $ghVersion = gh --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "GitHub CLI is installed"
        } else {
            $missing += "GitHub CLI"
        }
    } catch {
        $missing += "GitHub CLI"
    }
    
    # Check Node.js
    try {
        $nodeVersion = node --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Node.js is installed: $nodeVersion"
        } else {
            $missing += "Node.js"
        }
    } catch {
        $missing += "Node.js"
    }
    
    # Check Python
    try {
        $pythonVersion = python --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Python is installed: $pythonVersion"
        } else {
            $missing += "Python"
        }
    } catch {
        $missing += "Python"
    }
    
    # Check Docker
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker is installed: $dockerVersion"
        } else {
            $missing += "Docker"
        }
    } catch {
        $missing += "Docker"
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing prerequisites: $($missing -join ', ')"
        Write-ColorOutput "Please install the missing tools and run this script again." "Yellow"
        exit 1
    }
    
    Write-Success "All prerequisites are met"
}

# Setup Azure resources
function Setup-AzureResources {
    if ($SkipAzureSetup) {
        Write-Warning "Skipping Azure setup as requested"
        return
    }
    
    Write-Step "Setting up Azure resources..."
    
    # Login to Azure
    Write-ColorOutput "Logging into Azure..." "Cyan"
    az login
    
    if ($AzureSubscriptionId) {
        az account set --subscription $AzureSubscriptionId
        Write-Success "Set subscription to $AzureSubscriptionId"
    }
    
    # Create service principal for GitHub Actions
    Write-ColorOutput "Creating service principal for GitHub Actions..." "Cyan"
    
    $spName = "github-actions-wix-platform-$(Get-Random)"
    
    # Get the current subscription ID
    $subscriptionId = (az account show --query id --output tsv)
    
    $spJson = az ad sp create-for-rbac --name $spName --role Contributor --scopes "/subscriptions/$subscriptionId" --sdk-auth | ConvertFrom-Json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Service principal created: $spName"
        
        # Store credentials for later use
        $Global:AzureCredentials = @{
            ClientId = $spJson.clientId
            ClientSecret = $spJson.clientSecret
            TenantId = $spJson.tenantId
            SubscriptionId = $spJson.subscriptionId
        }
        
        # Grant additional permissions
        Write-ColorOutput "Granting additional permissions..." "Cyan"
        
        # Key Vault permissions
        az role assignment create --assignee $spJson.clientId --role "Key Vault Secrets User" --scope "/subscriptions/$subscriptionId"
        
        # Container Registry permissions
        az role assignment create --assignee $spJson.clientId --role "AcrPush" --scope "/subscriptions/$subscriptionId"
        
        Write-Success "Additional permissions granted"
    } else {
        Write-Error "Failed to create service principal"
        exit 1
    }
}

# Setup GitHub repository
function Setup-GitHubRepository {
    if ($SkipGitHubSetup) {
        Write-Warning "Skipping GitHub setup as requested"
        return
    }
    
    Write-Step "Setting up GitHub repository..."
    
    # Authenticate with GitHub
    if ($GitHubToken) {
        $env:GH_TOKEN = $GitHubToken
    } else {
        Write-ColorOutput "Authenticating with GitHub..." "Cyan"
        gh auth login
    }
    
    # Check if we're in a GitHub repository
    $repoInfo = gh repo view --json nameWithOwner 2>$null | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not in a GitHub repository or not authenticated"
        exit 1
    }
    
    $repoName = $repoInfo.nameWithOwner
    Write-Success "Working with repository: $repoName"
    
    # Set up repository secrets
    Setup-GitHubSecrets
    
    # Enable GitHub features
    Write-ColorOutput "Enabling GitHub features..." "Cyan"
    
    # Enable vulnerability alerts
    gh api repos/$repoName/vulnerability-alerts -X PUT
    
    # Enable dependency alerts
    gh api repos/$repoName/automated-security-fixes -X PUT
    
    Write-Success "GitHub features enabled"
}

# Setup GitHub secrets
function Setup-GitHubSecrets {
    Write-ColorOutput "Setting up GitHub secrets..." "Cyan"
    
    if ($Global:AzureCredentials) {
        # Set Azure credentials
        gh secret set AZURE_CLIENT_ID --body $Global:AzureCredentials.ClientId
        gh secret set AZURE_CLIENT_SECRET --body $Global:AzureCredentials.ClientSecret
        gh secret set AZURE_TENANT_ID --body $Global:AzureCredentials.TenantId
        gh secret set AZURE_SUBSCRIPTION_ID --body $Global:AzureCredentials.SubscriptionId
        
        Write-Success "Azure credentials set as GitHub secrets"
    }
    
    # Prompt for other required secrets
    $requiredSecrets = @(
        @{ Name = "OPENAI_API_KEY"; Description = "OpenAI API key for AI code review" },
        @{ Name = "SNYK_TOKEN"; Description = "Snyk authentication token" },
        @{ Name = "SONAR_TOKEN"; Description = "SonarCloud authentication token" }
    )
    
    foreach ($secret in $requiredSecrets) {
        $value = Read-Host "Enter $($secret.Description) (leave empty to skip)"
        if ($value) {
            gh secret set $secret.Name --body $value
            Write-Success "Set secret: $($secret.Name)"
        } else {
            Write-Warning "Skipped secret: $($secret.Name)"
        }
    }
    
    # Optional secrets
    $optionalSecrets = @(
        @{ Name = "SLACK_WEBHOOK_URL"; Description = "Slack webhook URL for notifications" },
        @{ Name = "CODECOV_TOKEN"; Description = "Codecov authentication token" },
        @{ Name = "SEMGREP_APP_TOKEN"; Description = "Semgrep app token" }
    )
    
    foreach ($secret in $optionalSecrets) {
        $value = Read-Host "Enter $($secret.Description) (optional)"
        if ($value) {
            gh secret set $secret.Name --body $value
            Write-Success "Set secret: $($secret.Name)"
        }
    }
}

# Setup pre-commit hooks
function Setup-PreCommitHooks {
    Write-Step "Setting up pre-commit hooks..."
    
    # Install pre-commit if not already installed
    try {
        pre-commit --version 2>$null
        Write-Success "pre-commit is already installed"
    } catch {
        Write-ColorOutput "Installing pre-commit..." "Cyan"
        pip install pre-commit
    }
    
    # Install hooks
    if (Test-Path ".pre-commit-config.yaml") {
        Write-ColorOutput "Installing pre-commit hooks..." "Cyan"
        pre-commit install
        pre-commit install --hook-type commit-msg
        Write-Success "Pre-commit hooks installed"
        
        # Run initial check
        Write-ColorOutput "Running initial pre-commit check..." "Cyan"
        pre-commit run --all-files
    } else {
        Write-Warning ".pre-commit-config.yaml not found, skipping pre-commit setup"
    }
}

# Setup development environment
function Setup-DevelopmentEnvironment {
    Write-Step "Setting up development environment..."
    
    # Install npm dependencies
    if (Test-Path "package.json") {
        Write-ColorOutput "Installing npm dependencies..." "Cyan"
        npm install
        Write-Success "npm dependencies installed"
    }
    
    # Install package dependencies
    if (Test-Path "packages") {
        Write-ColorOutput "Installing package dependencies..." "Cyan"
        
        $packages = Get-ChildItem -Path "packages" -Directory
        foreach ($package in $packages) {
            $packageJsonPath = Join-Path $package.FullName "package.json"
            if (Test-Path $packageJsonPath) {
                Write-ColorOutput "Installing dependencies for $($package.Name)..." "Cyan"
                Push-Location $package.FullName
                npm install
                Pop-Location
            }
        }
        
        Write-Success "All package dependencies installed"
    }
    
    # Setup Python virtual environment for microservices
    $microservicesPath = "packages\microservices"
    if (Test-Path $microservicesPath) {
        Write-ColorOutput "Setting up Python virtual environment..." "Cyan"
        Push-Location $microservicesPath
        
        python -m venv venv
        .\venv\Scripts\Activate.ps1
        pip install -r requirements.txt
        pip install pytest pytest-cov flake8 black mypy bandit
        
        Pop-Location
        Write-Success "Python environment setup completed"
    }
}

# Validate setup
function Test-Setup {
    Write-Step "Validating setup..."
    
    $issues = @()
    
    # Check if workflows exist
    $workflowsPath = ".github\workflows"
    if (Test-Path $workflowsPath) {
        $workflows = Get-ChildItem -Path $workflowsPath -Filter "*.yml"
        if ($workflows.Count -gt 0) {
            Write-Success "Found $($workflows.Count) GitHub workflow(s)"
        } else {
            $issues += "No GitHub workflows found"
        }
    } else {
        $issues += "GitHub workflows directory not found"
    }
    
    # Check if secrets are configured
    try {
        $secrets = gh secret list --json name | ConvertFrom-Json
        $requiredSecrets = @("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID")
        $missingSecrets = $requiredSecrets | Where-Object { $_.name -notin $secrets.name }
        
        if ($missingSecrets.Count -eq 0) {
            Write-Success "All required secrets are configured"
        } else {
            $issues += "Missing required secrets: $($missingSecrets -join ', ')"
        }
    } catch {
        $issues += "Could not verify GitHub secrets"
    }
    
    # Check if Azure CLI is authenticated
    try {
        $account = az account show | ConvertFrom-Json
        Write-Success "Azure CLI is authenticated as $($account.user.name)"
    } catch {
        $issues += "Azure CLI is not authenticated"
    }
    
    if ($issues.Count -gt 0) {
        Write-Warning "Setup validation found issues:"
        foreach ($issue in $issues) {
            Write-ColorOutput "  - $issue" "Yellow"
        }
    } else {
        Write-Success "All setup validation checks passed!"
    }
}

# Generate summary report
function Write-SetupSummary {
    Write-Step "Setup Summary"
    
    Write-ColorOutput @"

🚀 AI-Powered CI/CD Setup Complete!

Your Wix Platform now includes:

✅ SECURITY & QUALITY
  - Secret scanning (TruffleHog, GitLeaks)
  - SAST analysis (Semgrep, SonarCloud)
  - Dependency scanning (Snyk, Dependabot)
  - Container security (Trivy)
  - Pre-commit hooks for quality gates

✅ AI-POWERED FEATURES
  - AI code review with OpenAI/CodeRabbit
  - Automated quality gates
  - Intelligent rollback decisions
  - Performance regression detection

✅ DEPLOYMENT & MONITORING
  - Blue-green deployment with Azure slots
  - Automated health checks
  - Real-time monitoring & alerting
  - Performance testing integration

✅ DEVELOPMENT WORKFLOW
  - Multi-environment support (dev/staging/prod)
  - Automated testing matrix
  - Docker containerization
  - Infrastructure as Code (Bicep)

📋 NEXT STEPS:
  1. Commit and push your changes to trigger the first pipeline run
  2. Review the GitHub Actions tabs for workflow status
  3. Configure any remaining optional secrets
  4. Customize performance budgets and security rules
  5. Set up monitoring dashboards in Azure

📚 DOCUMENTATION:
  - GITHUB_SECRETS_GUIDE.md - Complete secrets setup guide
  - SECURITY_GUIDE.md - Security configuration details
  - PERFORMANCE_TESTING_GUIDE.md - Performance testing setup
  - DEPLOYMENT_MONITORING_GUIDE.md - Monitoring and rollback procedures

🆘 SUPPORT:
  - Check workflow logs in GitHub Actions
  - Review Azure Application Insights for runtime issues
  - Run scripts/validate-secrets.ps1 to verify configuration

Happy coding! 🎉

"@ "Green"
}

# Main execution
function Main {
    Write-ColorOutput @"

🤖 AI-Powered CI/CD Setup for Wix Platform
==========================================

This script will set up a comprehensive AI-powered CI/CD pipeline including:
- Azure cloud infrastructure
- GitHub Actions workflows
- Security scanning and secret management
- AI code review and quality gates
- Performance monitoring and automated rollback
- Development environment configuration

"@ "Cyan"
    
    try {
        Test-Prerequisites
        
        if (-not $SkipAzureSetup) {
            Setup-AzureResources
        }
        
        if (-not $SkipGitHubSetup) {
            Setup-GitHubRepository
        }
        
        Setup-PreCommitHooks
        Setup-DevelopmentEnvironment
        Test-Setup
        Write-SetupSummary
        
        Write-Success "Setup completed successfully!"
        
    } catch {
        Write-Error "Setup failed: $($_.Exception.Message)"
        Write-ColorOutput "Please check the error above and try again." "Yellow"
        exit 1
    }
}

# Execute main function
Main
