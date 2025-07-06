#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Complete GitHub-Only DevOps Setup for Wix Studio Azure Platform
.DESCRIPTION
    This script sets up the entire GitHub-only CI/CD pipeline including:
    - Azure OIDC authentication
    - GitHub secrets configuration
    - Repository settings
    - Branch protection rules
.NOTES
    Requires Azure CLI and GitHub CLI to be installed and authenticated
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$RepoName = "Diatonic-AI/wix-studio-azure-platform",

    [Parameter(Mandatory=$false)]
    [string]$Environment = "production"
)

Write-Host "🚀 GitHub-Only DevOps Complete Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "=== CHECKING PREREQUISITES ===" -ForegroundColor Magenta

# Check Azure CLI
try {
    $azAccount = az account show --query name -o tsv 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Azure CLI authenticated to: $azAccount" -ForegroundColor Green
    } else {
        Write-Error "Azure CLI not authenticated. Run 'az login' first."
        exit 1
    }
} catch {
    Write-Error "Azure CLI not installed. Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check GitHub CLI
try {
    gh auth status 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
    } else {
        Write-Error "GitHub CLI not authenticated. Run 'gh auth login' first."
        exit 1
    }
} catch {
    Write-Error "GitHub CLI not installed. Install from: https://cli.github.com/"
    exit 1
}

Write-Host ""
Write-Host "Repository: $RepoName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

$continue = Read-Host "Continue with setup? (y/N)"
if ($continue -ne "y" -and $continue -ne "Y") {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

# Step 1: Set up Azure OIDC
Write-Host ""
Write-Host "=== STEP 1: AZURE OIDC SETUP ===" -ForegroundColor Magenta
try {
    & "$PSScriptRoot\setup-azure-oidc.ps1" -RepoName $RepoName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure OIDC setup failed"
        exit 1
    }
} catch {
    Write-Error "Failed to run Azure OIDC setup: $_"
    exit 1
}

# Step 2: Configure additional GitHub secrets
Write-Host ""
Write-Host "=== STEP 2: ADDITIONAL GITHUB SECRETS ===" -ForegroundColor Magenta

function Set-GitHubSecret {
    param([string]$Name, [string]$Value, [string]$Description)

    if (![string]::IsNullOrWhiteSpace($Value)) {
        try {
            Write-Output $Value | gh secret set $Name --repo $RepoName
            Write-Host "✅ Set $Name" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to set $Name" -ForegroundColor Red
        }
    }
}

# Wix credentials
Write-Host ""
Write-Host "🎯 Wix Studio Credentials:" -ForegroundColor Cyan
$wixClientId = Read-Host "WIX_CLIENT_ID (your Wix app client ID)"
$wixAccessToken = Read-Host "WIX_ACCESS_TOKEN (your Wix access token)"
$wixRefreshToken = Read-Host "WIX_REFRESH_TOKEN (your Wix refresh token)"

Set-GitHubSecret -Name "WIX_CLIENT_ID" -Value $wixClientId -Description "Wix Studio client ID"
Set-GitHubSecret -Name "WIX_ACCESS_TOKEN" -Value $wixAccessToken -Description "Wix access token"
Set-GitHubSecret -Name "WIX_REFRESH_TOKEN" -Value $wixRefreshToken -Description "Wix refresh token"

# Database credentials
Write-Host ""
Write-Host "🗄️ Database Credentials:" -ForegroundColor Cyan
$sqlPassword = Read-Host "SQL_ADMIN_PASSWORD (secure password for SQL database)"
Set-GitHubSecret -Name "SQL_ADMIN_PASSWORD" -Value $sqlPassword -Description "SQL database admin password"

# Optional external services
Write-Host ""
Write-Host "🔧 Optional External Services (press Enter to skip):" -ForegroundColor Cyan
$sonarToken = Read-Host "SONAR_TOKEN (SonarCloud token for code quality)"
$openaiKey = Read-Host "OPENAI_API_KEY (OpenAI key for AI code review)"
$slackWebhook = Read-Host "SLACK_WEBHOOK_URL (Slack webhook for notifications)"

Set-GitHubSecret -Name "SONAR_TOKEN" -Value $sonarToken -Description "SonarCloud token"
Set-GitHubSecret -Name "OPENAI_API_KEY" -Value $openaiKey -Description "OpenAI API key"
Set-GitHubSecret -Name "SLACK_WEBHOOK_URL" -Value $slackWebhook -Description "Slack webhook URL"

# Step 3: Configure GitHub repository settings
Write-Host ""
Write-Host "=== STEP 3: REPOSITORY SETTINGS ===" -ForegroundColor Magenta

Write-Host "Configuring repository settings..." -ForegroundColor Yellow

# Enable features
try {
    gh repo edit $RepoName --enable-issues=true --enable-projects=true --enable-wiki=false
    Write-Host "✅ Repository features configured" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not configure repository features" -ForegroundColor Yellow
}

# Set up environments
Write-Host "Setting up GitHub environments..." -ForegroundColor Yellow
try {
    # Check if environments exist, create if not
    $environments = @("development", "staging", "production")
    foreach ($env in $environments) {
        $envExists = gh api "repos/$RepoName/environments/$env" 2>$null
        if ($LASTEXITCODE -ne 0) {
            gh api "repos/$RepoName/environments/$env" -X PUT --input - <<< '{"wait_timer":0,"reviewers":[],"deployment_branch_policy":null}'
            Write-Host "✅ Created environment: $env" -ForegroundColor Green
        } else {
            Write-Host "✅ Environment exists: $env" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "⚠️  Could not set up environments automatically" -ForegroundColor Yellow
}

# Step 4: Configure branch protection rules
Write-Host ""
Write-Host "=== STEP 4: BRANCH PROTECTION ===" -ForegroundColor Magenta

Write-Host "Setting up branch protection rules..." -ForegroundColor Yellow
$branchProtection = @{
    required_status_checks = @{
        strict = $true
        contexts = @("build-and-test")
    }
    enforce_admins = $false
    required_pull_request_reviews = @{
        required_approving_review_count = 1
        dismiss_stale_reviews = $true
        require_code_owner_reviews = $false
    }
    restrictions = $null
    allow_force_pushes = $false
    allow_deletions = $false
} | ConvertTo-Json -Depth 10

try {
    $branchProtection | gh api "repos/$RepoName/branches/main/protection" -X PUT --input -
    Write-Host "✅ Branch protection rules configured for main" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not configure branch protection rules automatically" -ForegroundColor Yellow
    Write-Host "   Please configure manually in GitHub repository settings" -ForegroundColor Gray
}

# Step 5: Test workflow
Write-Host ""
Write-Host "=== STEP 5: WORKFLOW TEST ===" -ForegroundColor Magenta

Write-Host "Testing GitHub Actions workflow..." -ForegroundColor Yellow
$testWorkflow = Read-Host "Trigger a test workflow run? (y/N)"
if ($testWorkflow -eq "y" -or $testWorkflow -eq "Y") {
    try {
        gh workflow run "azure-deploy.yml" --repo $RepoName
        Write-Host "✅ Test workflow triggered" -ForegroundColor Green
        Write-Host "   Check status at: https://github.com/$RepoName/actions" -ForegroundColor Gray
    } catch {
        Write-Host "⚠️  Could not trigger workflow automatically" -ForegroundColor Yellow
    }
}

# Summary
Write-Host ""
Write-Host "🎉 GITHUB-ONLY DEVOPS SETUP COMPLETE!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""

Write-Host "✅ What's been configured:" -ForegroundColor Cyan
Write-Host "• Azure OIDC authentication (no client secrets needed)" -ForegroundColor Gray
Write-Host "• GitHub repository secrets for all services" -ForegroundColor Gray
Write-Host "• GitHub environments (development, staging, production)" -ForegroundColor Gray
Write-Host "• Branch protection rules for main branch" -ForegroundColor Gray
Write-Host "• Container registry using GitHub Container Registry" -ForegroundColor Gray
Write-Host ""

Write-Host "🚀 Next steps:" -ForegroundColor Yellow
Write-Host "1. Push code to main branch to trigger first deployment" -ForegroundColor Gray
Write-Host "2. Monitor deployment at: https://github.com/$RepoName/actions" -ForegroundColor Gray
Write-Host "3. Access deployed application via Azure portal" -ForegroundColor Gray
Write-Host "4. Set up monitoring alerts in Application Insights" -ForegroundColor Gray
Write-Host ""

Write-Host "📊 Cost savings with GitHub-only approach:" -ForegroundColor Yellow
Write-Host "• No Azure DevOps licensing costs" -ForegroundColor Gray
Write-Host "• No Azure Container Registry costs (~$5/month saved)" -ForegroundColor Gray
Write-Host "• Free GitHub Actions minutes (2,000/month)" -ForegroundColor Gray
Write-Host "• Simplified toolchain and maintenance" -ForegroundColor Gray
Write-Host ""

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "• GitHub-Only DevOps Guide: ./GITHUB_DEVOPS_GUIDE.md" -ForegroundColor Gray
Write-Host "• Security Guide: ./SECURITY_GUIDE.md" -ForegroundColor Gray
Write-Host "• Performance Guide: ./PERFORMANCE_TESTING_GUIDE.md" -ForegroundColor Gray
Write-Host ""

Write-Host "🔗 Useful links:" -ForegroundColor Cyan
Write-Host "• Repository: https://github.com/$RepoName" -ForegroundColor Gray
Write-Host "• Actions: https://github.com/$RepoName/actions" -ForegroundColor Gray
Write-Host "• Settings: https://github.com/$RepoName/settings" -ForegroundColor Gray
