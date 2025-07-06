# Git GPG Configuration Script for Wix Studio Azure Platform
# PowerShell version for Windows

Write-Host "Configuring Git with GPG signing requirements..." -ForegroundColor Cyan

# Set required user information
Write-Host "Setting user information..." -ForegroundColor Green
git config user.name "iamdrewfortini"
git config user.email "admin@diatonic.online"

# Enable GPG signing globally
Write-Host "Enabling GPG commit signing..." -ForegroundColor Green
git config commit.gpgsign true

# Set GPG program path (Windows)
Write-Host "Setting GPG program path..." -ForegroundColor Green
git config gpg.program "C:\Program Files (x86)\GnuPG\bin\gpg.exe"

# Set signing key
Write-Host "Setting GPG signing key..." -ForegroundColor Green
git config user.signingkey "70B818F755466DCD"

# Set commit message template
Write-Host "Setting commit message template..." -ForegroundColor Green
git config commit.template ".gitmessage"

# Configure other security settings
Write-Host "Configuring security settings..." -ForegroundColor Green
git config push.followTags true
git config tag.forceSignAnnotated true
git config tag.gpgSign true

# Configure merge/rebase settings
Write-Host "Configuring merge/rebase settings..." -ForegroundColor Green
git config merge.verifySignatures true
git config pull.rebase true

# Display current configuration
Write-Host ""
Write-Host "Git configuration completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Current configuration:" -ForegroundColor Yellow
Write-Host "User: $(git config user.name) <$(git config user.email)>"
Write-Host "GPG Signing: $(git config commit.gpgsign)"
Write-Host "Signing Key: $(git config user.signingkey)"
Write-Host "GPG Program: $(git config gpg.program)"
Write-Host ""

# Test GPG key
Write-Host "Testing GPG key..." -ForegroundColor Yellow
try {
    $gpgOutput = & "C:\Program Files (x86)\GnuPG\bin\gpg.exe" --list-secret-keys --keyid-format LONG 2>$null
    $signingKey = git config user.signingkey

    if ($gpgOutput -match $signingKey) {
        Write-Host "GPG key found and accessible" -ForegroundColor Green
    } else {
        Write-Host "GPG key not found or not accessible" -ForegroundColor Red
        Write-Host "Please ensure your GPG key is properly imported and accessible" -ForegroundColor Red
    }
} catch {
    Write-Host "Could not access GPG. Please check installation." -ForegroundColor Red
}

Write-Host ""
Write-Host "Setup complete! All commits will now be GPG signed automatically." -ForegroundColor Green
Write-Host ""
Write-Host "Commit flags for deployment:" -ForegroundColor Cyan
Write-Host "  [dev] - triggers development deployment"
Write-Host "  [staging] - triggers staging deployment"
Write-Host "  [prod] - triggers production deployment"
Write-Host ""
Write-Host "Example commit:" -ForegroundColor Cyan
Write-Host '  git commit -m "feat(auth): add OIDC authentication [dev]"'
