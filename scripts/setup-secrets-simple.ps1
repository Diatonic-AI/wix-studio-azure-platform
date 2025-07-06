# Simple GitHub Secrets Setup Script

param(
    [string]$Repository = "Diatonic-AI/wix-studio-azure-platform"
)

Write-Host "Setting up GitHub Secrets for: $Repository" -ForegroundColor Green

# Check GitHub CLI
Write-Host "Checking GitHub CLI..." -ForegroundColor Yellow
try {
    gh auth status | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
    } else {
        Write-Host "❌ GitHub CLI not authenticated. Run: gh auth login" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ GitHub CLI not found. Please install GitHub CLI" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "This script will prompt you for the following secrets:" -ForegroundColor Cyan
Write-Host "1. Azure credentials (required for deployment)"
Write-Host "2. Wix Studio credentials (required for API access)"
Write-Host "3. SQL password (required for database)"
Write-Host "4. Optional service tokens"
Write-Host ""

$continue = Read-Host "Continue? (y/N)"
if ($continue -ne "y" -and $continue -ne "Y") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# Helper function to set secrets
function Set-Secret {
    param([string]$Name, [string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Host "⚠️  Skipping $Name (no value)" -ForegroundColor Yellow
        return
    }

    Write-Host "Setting $Name..." -ForegroundColor Yellow
    try {
        $Value | gh secret set $Name --repo $Repository
        Write-Host "✅ $Name set successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to set $Name" -ForegroundColor Red
    }
}

# Collect Azure credentials
Write-Host ""
Write-Host "=== AZURE CREDENTIALS ===" -ForegroundColor Magenta
$azureClientId = Read-Host "Azure Client ID (required)"
$azureClientSecret = Read-Host "Azure Client Secret (required)" -AsSecureString
$azureTenantId = Read-Host "Azure Tenant ID (required)"
$azureSubscriptionId = Read-Host "Azure Subscription ID (required)"

# Convert secure string back to plain text for GitHub secrets
$azureClientSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($azureClientSecret))

# Collect Wix credentials
Write-Host ""
Write-Host "=== WIX STUDIO CREDENTIALS ===" -ForegroundColor Magenta
$wixClientId = Read-Host "Wix Client ID (required)"
$wixAccessToken = Read-Host "Wix Access Token (required)" -AsSecureString
$wixRefreshToken = Read-Host "Wix Refresh Token (required)" -AsSecureString

# Convert secure strings
$wixAccessTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($wixAccessToken))
$wixRefreshTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($wixRefreshToken))

# Collect database password
Write-Host ""
Write-Host "=== DATABASE CREDENTIALS ===" -ForegroundColor Magenta
$sqlPassword = Read-Host "SQL Admin Password (required)" -AsSecureString
$sqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPassword))

# Optional tokens
Write-Host ""
Write-Host "=== OPTIONAL SERVICES ===" -ForegroundColor Magenta
$sonarToken = Read-Host "SonarCloud Token (optional, press Enter to skip)"
$openaiKey = Read-Host "OpenAI API Key (optional, press Enter to skip)"
$slackWebhook = Read-Host "Slack Webhook URL (optional, press Enter to skip)"

# Set all secrets
Write-Host ""
Write-Host "=== SETTING SECRETS ===" -ForegroundColor Magenta

Set-Secret "AZURE_CLIENT_ID" $azureClientId
Set-Secret "AZURE_CLIENT_SECRET" $azureClientSecretPlain
Set-Secret "AZURE_TENANT_ID" $azureTenantId
Set-Secret "AZURE_SUBSCRIPTION_ID" $azureSubscriptionId

Set-Secret "WIX_CLIENT_ID" $wixClientId
Set-Secret "WIX_ACCESS_TOKEN" $wixAccessTokenPlain
Set-Secret "WIX_REFRESH_TOKEN" $wixRefreshTokenPlain

Set-Secret "SQL_ADMIN_PASSWORD" $sqlPasswordPlain

if ($sonarToken) { Set-Secret "SONAR_TOKEN" $sonarToken }
if ($openaiKey) { Set-Secret "OPENAI_API_KEY" $openaiKey }
if ($slackWebhook) { Set-Secret "SLACK_WEBHOOK_URL" $slackWebhook }

Write-Host ""
Write-Host "🎉 GitHub Secrets Setup Complete!" -ForegroundColor Green
Write-Host "Your repository is ready for CI/CD workflows." -ForegroundColor Green
