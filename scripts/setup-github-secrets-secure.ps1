#Requires -Version 5.1

<#
.SYNOPSIS
    Set up required GitHub secrets for the Wix Studio Azure Platform CI/CD workflows
.DESCRIPTION
    This script helps configure all necessary GitHub secrets for the repository's
    GitHub Actions workflows including Azure credentials, Wix API keys, and other
    service tokens. This version is secure and does not contain any hardcoded credentials.
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
try {
    $null = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
        exit 1
    }
    Write-Host "✅ GitHub CLI is authenticated" -ForegroundColor Green
}
catch {
    Write-Error "GitHub CLI is not installed or not accessible. Please install GitHub CLI first."
    exit 1
}

# Function to set a secret securely
function Set-GitHubSecret {
    param(
        [string]$SecretName,
        [string]$SecretValue,
        [string]$Description
    )

    Write-Host "Setting secret: $SecretName" -ForegroundColor Yellow
    if ([string]::IsNullOrWhiteSpace($SecretValue)) {
        Write-Host "⚠️  Skipping $SecretName - no value provided" -ForegroundColor Yellow
        return $false
    }

    try {
        $SecretValue | gh secret set $SecretName --repo $Repository
        Write-Host "✅ Set $SecretName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Failed to set $SecretName : $_" -ForegroundColor Red
        return $false
    }
}

# Function to prompt for secret value
function Get-SecretValue {
    param(
        [string]$SecretName,
        [string]$Description,
        [bool]$Required = $true,
        [bool]$IsPassword = $false
    )

    Write-Host ""
    Write-Host "🔑 $SecretName" -ForegroundColor Cyan
    Write-Host "   $Description" -ForegroundColor Gray

    if ($Required) {
        do {
            if ($IsPassword) {
                $value = Read-Host "   Enter value (required)" -AsSecureString
                $value = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($value))
            } else {
                $value = Read-Host "   Enter value (required)"
            }
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Host "   This secret is required!" -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($value))
    } else {
        if ($IsPassword) {
            $value = Read-Host "   Enter value (optional, press Enter to skip)" -AsSecureString
            if ($value.Length -gt 0) {
                $value = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($value))
            } else {
                $value = ""
            }
        } else {
            $value = Read-Host "   Enter value (optional, press Enter to skip)"
        }
    }

    return $value
}

Write-Host ""
Write-Host "This script will help you set up the following GitHub secrets:" -ForegroundColor Green
Write-Host "• Azure service principal credentials for deployment"
Write-Host "• Wix Studio API credentials"
Write-Host "• External service tokens (optional)"
Write-Host ""
Write-Host "SECURITY NOTE: This script does not contain any hardcoded credentials." -ForegroundColor Green
Write-Host "You will need to provide your own Azure service principal credentials." -ForegroundColor Yellow
Write-Host ""

$continue = Read-Host "Continue? (y/N)"
if ($continue -ne "y" -and $continue -ne "Y") {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

# Step 1: Create Azure Service Principal (if needed)
Write-Host ""
Write-Host "=== STEP 1: AZURE SERVICE PRINCIPAL ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "First, let's create an Azure service principal for GitHub Actions to use." -ForegroundColor Yellow
Write-Host "This requires Azure CLI to be installed and logged in." -ForegroundColor Yellow
Write-Host ""

$createSP = Read-Host "Do you want to create a new Azure service principal? (y/N)"
if ($createSP -eq "y" -or $createSP -eq "Y") {
    Write-Host ""
    Write-Host "Creating Azure service principal..." -ForegroundColor Yellow

    try {
        # Get current subscription
        $subscription = az account show --query id -o tsv
        if ([string]::IsNullOrWhiteSpace($subscription)) {
            Write-Error "Please login to Azure CLI first: az login"
            exit 1
        }

        Write-Host "Using subscription: $subscription" -ForegroundColor Gray

        # Create service principal
        $spOutput = az ad sp create-for-rbac --name "github-actions-wix-studio-$(Get-Random)" --role "Contributor" --scopes "/subscriptions/$subscription" --sdk-auth

        if ($LASTEXITCODE -eq 0) {
            $spJson = $spOutput | ConvertFrom-Json
            Write-Host "✅ Service principal created successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "SAVE THESE CREDENTIALS (they will be used in the next step):" -ForegroundColor Yellow
            Write-Host "Client ID: $($spJson.clientId)" -ForegroundColor White
            Write-Host "Client Secret: $($spJson.clientSecret)" -ForegroundColor White
            Write-Host "Tenant ID: $($spJson.tenantId)" -ForegroundColor White
            Write-Host "Subscription ID: $($spJson.subscriptionId)" -ForegroundColor White
            Write-Host ""

            # Pre-fill values
            $azureClientId = $spJson.clientId
            $azureClientSecret = $spJson.clientSecret
            $azureTenantId = $spJson.tenantId
            $azureSubscriptionId = $spJson.subscriptionId
        } else {
            Write-Host "❌ Failed to create service principal. You'll need to provide credentials manually." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error creating service principal: $_" -ForegroundColor Red
        Write-Host "You'll need to provide credentials manually." -ForegroundColor Yellow
    }
}

# Azure Credentials (Required)
Write-Host ""
Write-Host "=== STEP 2: AZURE CREDENTIALS ===" -ForegroundColor Magenta

if ([string]::IsNullOrWhiteSpace($azureClientId)) {
    $azureClientId = Get-SecretValue -SecretName "AZURE_CLIENT_ID" -Description "Azure service principal client ID" -Required $true
}

if ([string]::IsNullOrWhiteSpace($azureClientSecret)) {
    $azureClientSecret = Get-SecretValue -SecretName "AZURE_CLIENT_SECRET" -Description "Azure service principal client secret" -Required $true -IsPassword $true
}

if ([string]::IsNullOrWhiteSpace($azureTenantId)) {
    $azureTenantId = Get-SecretValue -SecretName "AZURE_TENANT_ID" -Description "Azure Active Directory tenant ID" -Required $true
}

if ([string]::IsNullOrWhiteSpace($azureSubscriptionId)) {
    $azureSubscriptionId = Get-SecretValue -SecretName "AZURE_SUBSCRIPTION_ID" -Description "Azure subscription ID" -Required $true
}

# Wix Studio Credentials (Required)
Write-Host ""
Write-Host "=== STEP 3: WIX STUDIO CREDENTIALS ===" -ForegroundColor Magenta
$wixClientId = Get-SecretValue -SecretName "WIX_CLIENT_ID" -Description "Wix Studio app client ID" -Required $true
$wixAccessToken = Get-SecretValue -SecretName "WIX_ACCESS_TOKEN" -Description "Wix API access token" -Required $true -IsPassword $true
$wixRefreshToken = Get-SecretValue -SecretName "WIX_REFRESH_TOKEN" -Description "Wix API refresh token" -Required $true -IsPassword $true

# SQL Database Password (Required)
Write-Host ""
Write-Host "=== STEP 4: DATABASE CREDENTIALS ===" -ForegroundColor Magenta
$sqlAdminPassword = Get-SecretValue -SecretName "SQL_ADMIN_PASSWORD" -Description "SQL Database admin password (must be strong)" -Required $true -IsPassword $true

# Optional External Service Credentials
Write-Host ""
Write-Host "=== STEP 5: OPTIONAL EXTERNAL SERVICES ===" -ForegroundColor Magenta
$sonarToken = Get-SecretValue -SecretName "SONAR_TOKEN" -Description "SonarCloud token for code analysis" -Required $false -IsPassword $true
$openaiApiKey = Get-SecretValue -SecretName "OPENAI_API_KEY" -Description "OpenAI API key for AI code review" -Required $false -IsPassword $true
$slackWebhook = Get-SecretValue -SecretName "SLACK_WEBHOOK_URL" -Description "Slack webhook URL for notifications" -Required $false

# Set all secrets
Write-Host ""
Write-Host "=== SETTING GITHUB SECRETS ===" -ForegroundColor Magenta

$successCount = 0
$totalSecrets = 0

# Required Azure secrets
$totalSecrets++; if (Set-GitHubSecret -SecretName "AZURE_CLIENT_ID" -SecretValue $azureClientId -Description "Azure Client ID") { $successCount++ }
$totalSecrets++; if (Set-GitHubSecret -SecretName "AZURE_CLIENT_SECRET" -SecretValue $azureClientSecret -Description "Azure Client Secret") { $successCount++ }
$totalSecrets++; if (Set-GitHubSecret -SecretName "AZURE_TENANT_ID" -SecretValue $azureTenantId -Description "Azure Tenant ID") { $successCount++ }
$totalSecrets++; if (Set-GitHubSecret -SecretName "AZURE_SUBSCRIPTION_ID" -SecretValue $azureSubscriptionId -Description "Azure Subscription ID") { $successCount++ }

# Required Wix secrets
$totalSecrets++; if (Set-GitHubSecret -SecretName "WIX_CLIENT_ID" -SecretValue $wixClientId -Description "Wix Client ID") { $successCount++ }
$totalSecrets++; if (Set-GitHubSecret -SecretName "WIX_ACCESS_TOKEN" -SecretValue $wixAccessToken -Description "Wix Access Token") { $successCount++ }
$totalSecrets++; if (Set-GitHubSecret -SecretName "WIX_REFRESH_TOKEN" -SecretValue $wixRefreshToken -Description "Wix Refresh Token") { $successCount++ }

# Required SQL secret
$totalSecrets++; if (Set-GitHubSecret -SecretName "SQL_ADMIN_PASSWORD" -SecretValue $sqlAdminPassword -Description "SQL Admin Password") { $successCount++ }

# Optional secrets
if (-not [string]::IsNullOrWhiteSpace($sonarToken)) {
    $totalSecrets++; if (Set-GitHubSecret -SecretName "SONAR_TOKEN" -SecretValue $sonarToken -Description "SonarCloud Token") { $successCount++ }
}
if (-not [string]::IsNullOrWhiteSpace($openaiApiKey)) {
    $totalSecrets++; if (Set-GitHubSecret -SecretName "OPENAI_API_KEY" -SecretValue $openaiApiKey -Description "OpenAI API Key") { $successCount++ }
}
if (-not [string]::IsNullOrWhiteSpace($slackWebhook)) {
    $totalSecrets++; if (Set-GitHubSecret -SecretName "SLACK_WEBHOOK_URL" -SecretValue $slackWebhook -Description "Slack Webhook URL") { $successCount++ }
}

# Summary
Write-Host ""
Write-Host "=== SETUP SUMMARY ===" -ForegroundColor Magenta
Write-Host "Successfully set $successCount out of $totalSecrets secrets" -ForegroundColor $(if ($successCount -eq $totalSecrets) { "Green" } else { "Yellow" })

if ($successCount -eq $totalSecrets) {
    Write-Host ""
    Write-Host "🎉 GitHub secrets setup completed successfully!" -ForegroundColor Green
    Write-Host "Your repository is now ready for GitHub Actions deployment." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Push your code to trigger the CI/CD pipeline" -ForegroundColor White
    Write-Host "2. Monitor the GitHub Actions workflow" -ForegroundColor White
    Write-Host "3. Check Azure portal for deployed resources" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "⚠️  Some secrets failed to set. Please check the errors above." -ForegroundColor Yellow
    Write-Host "You can run this script again or set the missing secrets manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Repository: https://github.com/$Repository" -ForegroundColor Cyan
Write-Host "Secrets page: https://github.com/$Repository/settings/secrets/actions" -ForegroundColor Cyan
