#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Set up required GitHub secrets for the Wix Studio Azure Platform CI/CD workflows
.DESCRIPTION
    This script helps configure all necessary GitHub secrets for the repository's
    GitHub Actions workflows including Azure credentials, Wix API keys, and other
    service tokens.
.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Repository = "Diatonic-AI/wix-studio-azure-platform"
)

Write-Host "🔐 Setting up GitHub Secrets for $Repository" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check if GitHub CLI is authenticated
Write-Host "Checking GitHub CLI authentication..." -ForegroundColor Yellow
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
    exit 1
}
Write-Host "✅ GitHub CLI is authenticated" -ForegroundColor Green

# Function to set a secret
function Set-GitHubSecret {
    param(
        [string]$SecretName,
        [string]$SecretValue,
        [string]$Description
    )

    Write-Host "Setting secret: $SecretName" -ForegroundColor Yellow
    if ([string]::IsNullOrWhiteSpace($SecretValue)) {
        Write-Host "⚠️  Skipping $SecretName - no value provided" -ForegroundColor Yellow
        return
    }

    try {
        Write-Output $SecretValue | gh secret set $SecretName --repo $Repository
        Write-Host "✅ Set $SecretName" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to set $SecretName : $_" -ForegroundColor Red
    }
}

# Function to prompt for secret value
function Get-SecretValue {
    param(
        [string]$SecretName,
        [string]$Description,
        [bool]$Required = $true
    )

    Write-Host ""
    Write-Host "🔑 $SecretName" -ForegroundColor Cyan
    Write-Host "   $Description" -ForegroundColor Gray

    if ($Required) {
        $value = Read-Host "   Enter value (required)"
        while ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "   This secret is required!" -ForegroundColor Red
            $value = Read-Host "   Enter value (required)"
        }
    } else {
        $value = Read-Host "   Enter value (optional, press Enter to skip)"
    }

    return $value
}

Write-Host ""
Write-Host "This script will help you set up the following GitHub secrets:" -ForegroundColor Green
Write-Host "• Azure service principal credentials for deployment"
Write-Host "• Wix Studio API credentials"
Write-Host "• External service tokens (optional)"
Write-Host ""

$continue = Read-Host "Continue? (y/N)"
if ($continue -ne "y" -and $continue -ne "Y") {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

# Azure Credentials (Required)
Write-Host ""
Write-Host "=== AZURE CREDENTIALS (Required) ===" -ForegroundColor Magenta

$azureClientId = Get-SecretValue -SecretName "AZURE_CLIENT_ID" -Description "Azure service principal client ID (from Azure CLI: az ad sp create-for-rbac)"
$azureClientSecret = Get-SecretValue -SecretName "AZURE_CLIENT_SECRET" -Description "Azure service principal client secret"
$azureTenantId = Get-SecretValue -SecretName "AZURE_TENANT_ID" -Description "Azure tenant ID"
$azureSubscriptionId = Get-SecretValue -SecretName "AZURE_SUBSCRIPTION_ID" -Description "Azure subscription ID"

# Wix Studio Credentials (Required)
Write-Host ""
Write-Host "=== WIX STUDIO CREDENTIALS (Required) ===" -ForegroundColor Magenta

$wixClientId = Get-SecretValue -SecretName "WIX_CLIENT_ID" -Description "Wix Studio application client ID"
$wixAccessToken = Get-SecretValue -SecretName "WIX_ACCESS_TOKEN" -Description "Wix Studio access token"
$wixRefreshToken = Get-SecretValue -SecretName "WIX_REFRESH_TOKEN" -Description "Wix Studio refresh token"

# Database Passwords (Required)
Write-Host ""
Write-Host "=== DATABASE CREDENTIALS (Required) ===" -ForegroundColor Magenta

$sqlPassword = Get-SecretValue -SecretName "SQL_ADMIN_PASSWORD" -Description "SQL Server admin password (min 8 chars, complex)"

# Optional External Service Tokens
Write-Host ""
Write-Host "=== EXTERNAL SERVICES (Optional) ===" -ForegroundColor Magenta

$sonarToken = Get-SecretValue -SecretName "SONAR_TOKEN" -Description "SonarCloud token for code quality analysis" -Required $false
$openaiApiKey = Get-SecretValue -SecretName "OPENAI_API_KEY" -Description "OpenAI API key for AI code review" -Required $false
$slackWebhook = Get-SecretValue -SecretName "SLACK_WEBHOOK_URL" -Description "Slack webhook URL for notifications" -Required $false

# Set all secrets
Write-Host ""
Write-Host "=== SETTING SECRETS ===" -ForegroundColor Magenta

# Azure secrets
Set-GitHubSecret -SecretName "AZURE_CLIENT_ID" -SecretValue $azureClientId -Description "Azure service principal client ID"
Set-GitHubSecret -SecretName "AZURE_CLIENT_SECRET" -SecretValue $azureClientSecret -Description "Azure service principal secret"
Set-GitHubSecret -SecretName "AZURE_TENANT_ID" -SecretValue $azureTenantId -Description "Azure tenant ID"
Set-GitHubSecret -SecretName "AZURE_SUBSCRIPTION_ID" -SecretValue $azureSubscriptionId -Description "Azure subscription ID"

# Wix secrets
Set-GitHubSecret -SecretName "WIX_CLIENT_ID" -SecretValue $wixClientId -Description "Wix client ID"
Set-GitHubSecret -SecretName "WIX_ACCESS_TOKEN" -SecretValue $wixAccessToken -Description "Wix access token"
Set-GitHubSecret -SecretName "WIX_REFRESH_TOKEN" -SecretValue $wixRefreshToken -Description "Wix refresh token"

# Database secrets
Set-GitHubSecret -SecretName "SQL_ADMIN_PASSWORD" -SecretValue $sqlPassword -Description "SQL admin password"

# Optional external service secrets
if (![string]::IsNullOrWhiteSpace($sonarToken)) {
    Set-GitHubSecret -SecretName "SONAR_TOKEN" -SecretValue $sonarToken -Description "SonarCloud token"
}
if (![string]::IsNullOrWhiteSpace($openaiApiKey)) {
    Set-GitHubSecret -SecretName "OPENAI_API_KEY" -SecretValue $openaiApiKey -Description "OpenAI API key"
}
if (![string]::IsNullOrWhiteSpace($slackWebhook)) {
    Set-GitHubSecret -SecretName "SLACK_WEBHOOK_URL" -SecretValue $slackWebhook -Description "Slack webhook URL"
}

Write-Host ""
Write-Host "🎉 GitHub Secrets Setup Complete!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Your repository is now ready for CI/CD workflows." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Create Azure service principal: az ad sp create-for-rbac --name wix-studio-platform --role contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID" -ForegroundColor Gray
Write-Host "2. Configure Azure Key Vault with the same secrets" -ForegroundColor Gray
Write-Host "3. Test deployment with: git push origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "For more information, see GITHUB_SECRETS_GUIDE.md" -ForegroundColor Gray
