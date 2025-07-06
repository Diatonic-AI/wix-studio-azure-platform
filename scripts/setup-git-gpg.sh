#!/bin/bash
# Git GPG Configuration Script for Wix Studio Azure Platform

echo "🔧 Configuring Git with GPG signing requirements..."

# Set required user information
echo "👤 Setting user information..."
git config user.name "iamdrewfortini"
git config user.email "admin@diatonic.online"

# Enable GPG signing globally
echo "🔐 Enabling GPG commit signing..."
git config commit.gpgsign true

# Set GPG program path (Windows)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    git config gpg.program "C:\\Program Files (x86)\\GnuPG\\bin\\gpg.exe"
fi

# Set signing key (you may need to update this with your actual key ID)
echo "🔑 Setting GPG signing key..."
git config user.signingkey "70B818F755466DCD"

# Set commit message template
echo "📝 Setting commit message template..."
git config commit.template ".gitmessage"

# Configure other security settings
echo "🛡️ Configuring security settings..."
git config push.followTags true
git config tag.forceSignAnnotated true
git config tag.gpgSign true

# Configure merge/rebase settings
echo "🔄 Configuring merge/rebase settings..."
git config merge.verifySignatures true
git config pull.rebase true

# Display current configuration
echo ""
echo "✅ Git configuration completed!"
echo ""
echo "📋 Current configuration:"
echo "User: $(git config user.name) <$(git config user.email)>"
echo "GPG Signing: $(git config commit.gpgsign)"
echo "Signing Key: $(git config user.signingkey)"
echo "GPG Program: $(git config gpg.program)"
echo ""

# Test GPG key
echo "🧪 Testing GPG key..."
if gpg --list-secret-keys --keyid-format LONG | grep -q "$(git config user.signingkey)"; then
    echo "✅ GPG key found and accessible"
else
    echo "❌ GPG key not found or not accessible"
    echo "Please ensure your GPG key is properly imported and accessible"
fi

echo ""
echo "🎉 Setup complete! All commits will now be GPG signed automatically."
echo ""
echo "💡 Commit flags for deployment:"
echo "  [dev] - triggers development deployment"
echo "  [staging] - triggers staging deployment"
echo "  [prod] - triggers production deployment"
echo ""
echo "📖 Example commit:"
echo "  git commit -m \"feat(auth): add OIDC authentication [dev]\""
