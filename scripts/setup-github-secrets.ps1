#Requires -Version 5.1

<#
.SYNOPSIS
    Set up GitHub repository secrets for Wix Studio Azure Platform
.DESCRIPTION
    This script configures GitHub repository secrets by reading values from .env file
    for secure Azure deployment via GitHub Actions with OIDC authentication.
.NOTES
    - Requires GitHub CLI (gh) to be installed and authenticated
    - Requires .env file with all necessary credentials
    - Uses OIDC for secure Azure authentication (no client secrets needed in production)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Repository = "Diatonic-AI/wix-studio-azure-platform",
    
    [Parameter(Mandatory=$false)]
    [string]$EnvFile = ".env"
)

# Colors for console output
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Cyan = "Cyan"
$Gray = "Gray"

Write-Host "GitHub Secrets Setup for Wix Studio Platform" -ForegroundColor $Cyan
Write-Host "=================================================" -ForegroundColor $Cyan
Write-Host "Repository: $Repository" -ForegroundColor $Gray
Write-Host ""

# Function to read .env file
function Get-EnvValue {
    param([string]$Key)
    
    if (!(Test-Path $EnvFile)) {
        Write-Host "❌ .env file not found at: $EnvFile" -ForegroundColor $Red
        return $null
    }
    
    $content = Get-Content $EnvFile -ErrorAction SilentlyContinue
    foreach ($line in $content) {
        if ($line -match "^$Key\s*=\s*(.*)$") {
            return $matches[1].Trim('"').Trim("'")
        }
    }
    return $null
}

# Function to set GitHub secret
function Set-GitHubSecret {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Description = ""
    )
    
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Host "⚠️  Skipping $Name - no value provided" -ForegroundColor $Yellow
        return $false
    }
    
    try {
        Write-Host "Setting: $Name" -ForegroundColor $Gray
        $Value | gh secret set $Name --repo $Repository
        Write-Host "✅ $Name" -ForegroundColor $Green
        return $true
    }
    catch {
        Write-Host "❌ Failed to set ${Name}: $_" -ForegroundColor $Red
        return $false
    }
}

# Check GitHub CLI authentication
Write-Host "Checking GitHub CLI authentication..." -ForegroundColor $Yellow
try {
    $null = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ GitHub CLI not authenticated. Run 'gh auth login' first." -ForegroundColor $Red
        exit 1
    }
    Write-Host "✅ GitHub CLI authenticated" -ForegroundColor $Green
}
catch {
    Write-Host "❌ GitHub CLI not found. Please install GitHub CLI first." -ForegroundColor $Red
    exit 1
}

# Check .env file exists
if (!(Test-Path $EnvFile)) {
    Write-Host "❌ .env file not found: $EnvFile" -ForegroundColor $Red
    Write-Host "   Please create .env file with required credentials" -ForegroundColor $Yellow
    exit 1
}

Write-Host "✅ Found .env file: $EnvFile" -ForegroundColor $Green
Write-Host ""

# Read credentials from .env file
Write-Host "Reading credentials from .env file..." -ForegroundColor $Yellow

$credentials = @{
    # Azure credentials
    "AZURE_CLIENT_ID" = Get-EnvValue "AZURE_CLIENT_ID"
    "AZURE_TENANT_ID" = Get-EnvValue "AZURE_TENANT_ID" 
    "AZURE_SUBSCRIPTION_ID" = Get-EnvValue "AZURE_SUBSCRIPTION_ID"
    
    # Database credentials
    "SQL_ADMIN_PASSWORD" = Get-EnvValue "SQL_ADMIN_PASSWORD"
    
    # Wix Studio credentials
    "WIX_CLIENT_ID" = Get-EnvValue "WIX_CLIENT_ID"
    "WIX_ACCESS_TOKEN" = Get-EnvValue "WIX_ACCESS_TOKEN"
    "WIX_REFRESH_TOKEN" = Get-EnvValue "WIX_REFRESH_TOKEN"
}

# Validate required credentials
$requiredSecrets = @("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID", "SQL_ADMIN_PASSWORD")
$missingRequired = @()

foreach ($secret in $requiredSecrets) {
    if ([string]::IsNullOrWhiteSpace($credentials[$secret])) {
        $missingRequired += $secret
    }
}

if ($missingRequired.Count -gt 0) {
    Write-Host "❌ Missing required credentials in .env file:" -ForegroundColor $Red
    foreach ($missing in $missingRequired) {
        Write-Host "   - $missing" -ForegroundColor $Red
    }
    Write-Host ""
    Write-Host "Please add these to your .env file and run the script again." -ForegroundColor $Yellow
    exit 1
}

Write-Host "✅ All required credentials found" -ForegroundColor $Green
Write-Host ""

# Set GitHub secrets
Write-Host "Setting GitHub repository secrets..." -ForegroundColor $Cyan
Write-Host ""

$successCount = 0
$totalCount = 0

# Required Azure secrets
Write-Host "=== Azure Credentials (Required) ===" -ForegroundColor $Cyan
$azureSecrets = @("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID")
foreach ($secret in $azureSecrets) {
    $totalCount++
    if (Set-GitHubSecret -Name $secret -Value $credentials[$secret]) {
        $successCount++
    }
}

# Database secrets
Write-Host ""
Write-Host "=== Database Credentials (Required) ===" -ForegroundColor $Cyan
$totalCount++
if (Set-GitHubSecret -Name "SQL_ADMIN_PASSWORD" -Value $credentials["SQL_ADMIN_PASSWORD"]) {
    $successCount++
}

# Wix secrets (optional but recommended)
Write-Host ""
Write-Host "=== Wix Studio Credentials (Optional) ===" -ForegroundColor $Cyan
$wixSecrets = @("WIX_CLIENT_ID", "WIX_ACCESS_TOKEN", "WIX_REFRESH_TOKEN")
foreach ($secret in $wixSecrets) {
    $totalCount++
    if (Set-GitHubSecret -Name $secret -Value $credentials[$secret]) {
        $successCount++
    }
}

# Summary
Write-Host ""
Write-Host "Setup Summary" -ForegroundColor $Cyan
Write-Host "================" -ForegroundColor $Cyan
Write-Host "Secrets set successfully: $successCount/$totalCount" -ForegroundColor $(if ($successCount -eq $totalCount) { $Green } else { $Yellow })

if ($successCount -eq $totalCount) {
    Write-Host ""
    Write-Host "All secrets configured successfully!" -ForegroundColor $Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor $Cyan
    Write-Host "   1. Commit and push your code to trigger GitHub Actions" -ForegroundColor $Gray
    Write-Host "   2. Check the Actions tab for deployment status" -ForegroundColor $Gray
    Write-Host "   3. Monitor Azure resources in the portal" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "Repository: https://github.com/$Repository" -ForegroundColor $Gray
} else {
    Write-Host ""
    Write-Host "Some secrets failed to set. Please check the errors above." -ForegroundColor $Yellow
    Write-Host "   You can re-run this script after fixing the issues." -ForegroundColor $Yellow
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor $Green
