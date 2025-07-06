#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Set up Azure OIDC authentication for GitHub Actions (GitHub-Only DevOps)
.DESCRIPTION
    This script configures OpenID Connect (OIDC) between GitHub Actions and Azure,
    eliminating the need for client secrets and providing more secure authentication.
.PARAMETER RepoName
    The GitHub repository name in format "owner/repo"
.PARAMETER AppName
    The Azure app registration name (optional)
.NOTES
    Requires Azure CLI to be installed and authenticated
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoName,

    [Parameter(Mandatory=$false)]
    [string]$AppName = "wix-studio-github-oidc"
)

Write-Host "🚀 GitHub-Only DevOps: Azure OIDC Setup" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Repository: $RepoName" -ForegroundColor Yellow
Write-Host "App Name: $AppName" -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed and authenticated
Write-Host "Checking Azure CLI..." -ForegroundColor Yellow
try {
    $azAccount = az account show --query name -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure CLI is not authenticated. Please run 'az login' first."
        exit 1
    }
    Write-Host "✅ Authenticated to Azure account: $azAccount" -ForegroundColor Green
}
catch {
    Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI first."
    exit 1
}

# Get current subscription info
$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv
$subscriptionName = az account show --query name -o tsv

Write-Host ""
Write-Host "Current Azure Context:" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionName" -ForegroundColor Gray
Write-Host "Subscription ID: $subscriptionId" -ForegroundColor Gray
Write-Host "Tenant ID: $tenantId" -ForegroundColor Gray
Write-Host ""

$continue = Read-Host "Continue with this subscription? (y/N)"
if ($continue -ne "y" -and $continue -ne "Y") {
    Write-Host "Setup cancelled. Use 'az account set --subscription <name>' to change subscription." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=== STEP 1: Create Azure App Registration ===" -ForegroundColor Magenta

# Check if app already exists
$existingApp = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null
if (![string]::IsNullOrEmpty($existingApp)) {
    Write-Host "⚠️  App registration '$AppName' already exists with ID: $existingApp" -ForegroundColor Yellow
    $useExisting = Read-Host "Use existing app registration? (Y/n)"
    if ($useExisting -eq "n" -or $useExisting -eq "N") {
        $AppName = Read-Host "Enter a new app name"
        $existingApp = $null
    }
}

if ([string]::IsNullOrEmpty($existingApp)) {
    Write-Host "Creating Azure app registration: $AppName" -ForegroundColor Yellow
    try {
        $appId = az ad app create --display-name $AppName --query appId -o tsv
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create app registration"
            exit 1
        }
        Write-Host "✅ Created app registration with ID: $appId" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create app registration: $_"
        exit 1
    }
} else {
    $appId = $existingApp
    Write-Host "✅ Using existing app registration: $appId" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== STEP 2: Create Service Principal ===" -ForegroundColor Magenta

# Check if service principal exists
$existingSp = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv 2>$null
if ([string]::IsNullOrEmpty($existingSp)) {
    Write-Host "Creating service principal..." -ForegroundColor Yellow
    try {
        $spId = az ad sp create --id $appId --query id -o tsv
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create service principal"
            exit 1
        }
        Write-Host "✅ Created service principal with ID: $spId" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create service principal: $_"
        exit 1
    }
} else {
    Write-Host "✅ Service principal already exists" -ForegroundColor Green
    $spId = $existingSp
}

Write-Host ""
Write-Host "=== STEP 3: Assign Contributor Role ===" -ForegroundColor Magenta

Write-Host "Assigning Contributor role to subscription..." -ForegroundColor Yellow
try {
    az role assignment create --role "Contributor" --assignee $appId --scope "/subscriptions/$subscriptionId" --output none 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Assigned Contributor role" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Role assignment may already exist" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️  Role assignment may already exist or you may lack permissions" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== STEP 4: Configure OIDC Federated Credentials ===" -ForegroundColor Magenta

# Function to create federated credential
function New-FederatedCredential {
    param(
        [string]$Name,
        [string]$Subject,
        [string]$Description
    )

    Write-Host "Creating federated credential: $Name" -ForegroundColor Yellow

    $credentialJson = @{
        name = $Name
        issuer = "https://token.actions.githubusercontent.com"
        subject = $Subject
        audiences = @("api://AzureADTokenExchange")
        description = $Description
    } | ConvertTo-Json -Depth 3

    try {
        # Check if credential already exists
        $existing = az ad app federated-credential list --id $appId --query "[?name=='$Name'].name" -o tsv 2>$null
        if (![string]::IsNullOrEmpty($existing)) {
            Write-Host "⚠️  Federated credential '$Name' already exists" -ForegroundColor Yellow
            return
        }

        $result = az ad app federated-credential create --id $appId --parameters $credentialJson --output none
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Created federated credential: $Name" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to create federated credential: $Name" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error creating federated credential: $_" -ForegroundColor Red
    }
}

# Create federated credentials for different scenarios
New-FederatedCredential -Name "github-main" -Subject "repo:$RepoName:ref:refs/heads/main" -Description "Main branch deployments"
New-FederatedCredential -Name "github-develop" -Subject "repo:$RepoName:ref:refs/heads/develop" -Description "Develop branch deployments"
New-FederatedCredential -Name "github-pr" -Subject "repo:$RepoName:pull_request" -Description "Pull request workflows"
New-FederatedCredential -Name "github-environment-staging" -Subject "repo:$RepoName:environment:staging" -Description "Staging environment deployments"
New-FederatedCredential -Name "github-environment-production" -Subject "repo:$RepoName:environment:production" -Description "Production environment deployments"

Write-Host ""
Write-Host "=== STEP 5: GitHub Secrets Configuration ===" -ForegroundColor Magenta

Write-Host ""
Write-Host "🔐 Required GitHub Repository Secrets:" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "AZURE_CLIENT_ID" -ForegroundColor White -NoNewline
Write-Host " = " -ForegroundColor Gray -NoNewline
Write-Host "$appId" -ForegroundColor Green
Write-Host ""
Write-Host "AZURE_TENANT_ID" -ForegroundColor White -NoNewline
Write-Host " = " -ForegroundColor Gray -NoNewline
Write-Host "$tenantId" -ForegroundColor Green
Write-Host ""
Write-Host "AZURE_SUBSCRIPTION_ID" -ForegroundColor White -NoNewline
Write-Host " = " -ForegroundColor Gray -NoNewline
Write-Host "$subscriptionId" -ForegroundColor Green
Write-Host ""

Write-Host "📋 Copy these values to your GitHub repository secrets:" -ForegroundColor Yellow
Write-Host "1. Go to: https://github.com/$RepoName/settings/secrets/actions" -ForegroundColor Gray
Write-Host "2. Click 'New repository secret'" -ForegroundColor Gray
Write-Host "3. Add each secret with the values shown above" -ForegroundColor Gray
Write-Host ""

# Option to automatically set secrets if gh CLI is available
$ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
if ($ghAvailable) {
    Write-Host "GitHub CLI detected. Set secrets automatically? (y/N)" -ForegroundColor Yellow
    $autoSet = Read-Host
    if ($autoSet -eq "y" -or $autoSet -eq "Y") {
        Write-Host ""
        Write-Host "Setting GitHub secrets..." -ForegroundColor Yellow
        try {
            Write-Output $appId | gh secret set AZURE_CLIENT_ID --repo $RepoName
            Write-Output $tenantId | gh secret set AZURE_TENANT_ID --repo $RepoName
            Write-Output $subscriptionId | gh secret set AZURE_SUBSCRIPTION_ID --repo $RepoName
            Write-Host "✅ GitHub secrets set successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to set GitHub secrets automatically. Please set them manually." -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=== STEP 6: Update GitHub Actions Workflows ===" -ForegroundColor Magenta

Write-Host ""
Write-Host "🔧 Update your GitHub Actions workflows to use OIDC:" -ForegroundColor Cyan
Write-Host ""
Write-Host @"
# Add this to your workflow YAML:
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: `${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: `${{ secrets.AZURE_TENANT_ID }}
          subscription-id: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
"@ -ForegroundColor Gray

Write-Host ""
Write-Host "🎉 OIDC Setup Complete!" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Next Steps:" -ForegroundColor Cyan
Write-Host "1. Set the GitHub secrets (if not done automatically)" -ForegroundColor Gray
Write-Host "2. Update your GitHub Actions workflows to use OIDC" -ForegroundColor Gray
Write-Host "3. Remove AZURE_CLIENT_SECRET from your repository (no longer needed)" -ForegroundColor Gray
Write-Host "4. Test deployment by pushing to main branch" -ForegroundColor Gray
Write-Host ""
Write-Host "📚 Benefits of OIDC:" -ForegroundColor Yellow
Write-Host "• No client secrets to manage or rotate" -ForegroundColor Gray
Write-Host "• More secure authentication" -ForegroundColor Gray
Write-Host "• Automatic token management" -ForegroundColor Gray
Write-Host "• Granular permissions per repository" -ForegroundColor Gray
Write-Host ""
Write-Host "🔗 Documentation: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure" -ForegroundColor Gray
