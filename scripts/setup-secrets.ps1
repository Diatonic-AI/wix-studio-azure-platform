# Azure Key Vault Secrets Setup Script
# =====================================
# This script helps you add secrets to your Azure Key Vault
# Run this after deploying your infrastructure with 'azd up'

param(
  [Parameter(Mandatory = $false)]
  [string]$KeyVaultName,

  [Parameter(Mandatory = $false)]
  [string]$ResourceGroupName,

  [Parameter(Mandatory = $false)]
  [switch]$Interactive = $true
)

Write-Host "🔐 Azure Key Vault Secrets Setup" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Function to check if user is logged in to Azure
function Test-AzureLogin {
  try {
    $context = az account show 2>$null | ConvertFrom-Json
    if ($context) {
      Write-Host "✅ Logged in to Azure as: $($context.user.name)" -ForegroundColor Green
      Write-Host "📋 Subscription: $($context.name) ($($context.id))" -ForegroundColor Green
      return $true
    }
  } catch {
    return $false
  }
  return $false
}

# Function to get Key Vault name from azd environment
function Get-KeyVaultFromAzd {
  try {
    $azdOutput = azd env get-values 2>$null
    foreach ($line in $azdOutput) {
      if ($line -match "KEY_VAULT_NAME=(.+)") {
        return $matches[1].Trim('"')
      }
    }
  } catch {
    Write-Warning "Could not get Key Vault name from azd environment"
  }
  return $null
}

# Check Azure login
if (-not (Test-AzureLogin)) {
  Write-Host "❌ Not logged in to Azure. Please login first:" -ForegroundColor Red
  Write-Host "   azd auth login" -ForegroundColor Yellow
  exit 1
}

# Get Key Vault name
if (-not $KeyVaultName) {
  $KeyVaultName = Get-KeyVaultFromAzd

  if (-not $KeyVaultName -and $Interactive) {
    Write-Host ""
    Write-Host "🔍 Key Vault name not found automatically." -ForegroundColor Yellow
    $KeyVaultName = Read-Host "Please enter your Key Vault name"
  }

  if (-not $KeyVaultName) {
    Write-Host "❌ Key Vault name is required. Exiting." -ForegroundColor Red
    exit 1
  }
}

Write-Host ""
Write-Host "🏦 Using Key Vault: $KeyVaultName" -ForegroundColor Green

# Check if Key Vault exists and user has access
try {
  $vault = az keyvault show --name $KeyVaultName 2>$null | ConvertFrom-Json
  if (-not $vault) {
    Write-Host "❌ Key Vault '$KeyVaultName' not found or no access" -ForegroundColor Red
    exit 1
  }
  Write-Host "✅ Key Vault access confirmed" -ForegroundColor Green
} catch {
  Write-Host "❌ Error accessing Key Vault '$KeyVaultName'" -ForegroundColor Red
  exit 1
}

# Define secrets to add
$secrets = @(
  @{
    Name        = "wix-client-id"
    DisplayName = "Wix Studio Client ID"
    Description = "Your Wix Studio OAuth application client ID"
    Required    = $true
  },
  @{
    Name        = "wix-access-token"
    DisplayName = "Wix Studio Access Token"
    Description = "Your Wix Studio API access token"
    Required    = $true
  },
  @{
    Name        = "wix-refresh-token"
    DisplayName = "Wix Studio Refresh Token"
    Description = "Your Wix Studio OAuth refresh token"
    Required    = $true
  },
  @{
    Name        = "sql-admin-password"
    DisplayName = "SQL Database Admin Password"
    Description = "Strong password for SQL Database administrator"
    Required    = $true
  },
  @{
    Name        = "nextauth-secret"
    DisplayName = "NextAuth Secret"
    Description = "Random secret for NextAuth.js authentication"
    Required    = $false
  },
  @{
    Name        = "application-insights-key"
    DisplayName = "Application Insights Key"
    Description = "Application Insights instrumentation key"
    Required    = $false
  }
)

Write-Host ""
Write-Host "📝 Adding secrets to Key Vault..." -ForegroundColor Cyan
Write-Host ""

foreach ($secret in $secrets) {
  # Check if secret already exists
  $existingSecret = $null
  try {
    $existingSecret = az keyvault secret show --vault-name $KeyVaultName --name $secret.Name 2>$null | ConvertFrom-Json
  } catch {
    # Secret doesn't exist, which is fine
  }

  if ($existingSecret) {
    Write-Host "🔄 Secret '$($secret.Name)' already exists" -ForegroundColor Yellow
    if ($Interactive) {
      $overwrite = Read-Host "   Overwrite? (y/N)"
      if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "   ⏭️  Skipping '$($secret.Name)'" -ForegroundColor Gray
        continue
      }
    } else {
      Write-Host "   ⏭️  Skipping (use -Interactive to overwrite)" -ForegroundColor Gray
      continue
    }
  }

  if ($Interactive) {
    Write-Host "🔑 $($secret.DisplayName)" -ForegroundColor White
    Write-Host "   $($secret.Description)" -ForegroundColor Gray

    if ($secret.Required) {
      Write-Host "   (Required)" -ForegroundColor Red
    } else {
      Write-Host "   (Optional - press Enter to skip)" -ForegroundColor Gray
    }

    $secretValue = Read-Host -AsSecureString "   Enter value"
    $secretValuePlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretValue))

    if ([string]::IsNullOrWhiteSpace($secretValuePlain)) {
      if ($secret.Required) {
        Write-Host "   ❌ Required secret cannot be empty. Skipping." -ForegroundColor Red
        continue
      } else {
        Write-Host "   ⏭️  Skipping optional secret" -ForegroundColor Gray
        continue
      }
    }
  } else {
    # Non-interactive mode - generate some secrets
    switch ($secret.Name) {
      "nextauth-secret" {
        $secretValuePlain = [System.Web.Security.Membership]::GeneratePassword(32, 0)
        Write-Host "🔄 Generated NextAuth secret" -ForegroundColor Green
      }
      default {
        Write-Host "⏭️  Skipping '$($secret.Name)' in non-interactive mode" -ForegroundColor Gray
        continue
      }
    }
  }

  # Add secret to Key Vault
  try {
    $result = az keyvault secret set --vault-name $KeyVaultName --name $secret.Name --value $secretValuePlain 2>$null
    if ($result) {
      Write-Host "   ✅ Successfully added '$($secret.Name)'" -ForegroundColor Green
    } else {
      Write-Host "   ❌ Failed to add '$($secret.Name)'" -ForegroundColor Red
    }
  } catch {
    Write-Host "   ❌ Error adding '$($secret.Name)': $($_.Exception.Message)" -ForegroundColor Red
  }

  # Clear the plain text value from memory
  $secretValuePlain = $null
}

Write-Host ""
Write-Host "🎉 Key Vault secrets setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Restart your Azure App Services to pick up new secrets:"
Write-Host "      az webapp restart --name <your-app-name> --resource-group <your-rg>"
Write-Host ""
Write-Host "   2. Verify secrets are accessible in your applications:"
Write-Host "      Check application logs for any authentication errors"
Write-Host ""
Write-Host "   3. Test your Wix Studio integration:"
Write-Host "      Visit your application endpoints to verify functionality"

# Display Key Vault URL for reference
Write-Host ""
Write-Host "🔗 Key Vault URL: https://$KeyVaultName.vault.azure.net/" -ForegroundColor Blue
