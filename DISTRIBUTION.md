# Clarity Distribution Guide

This guide covers building, signing, and distributing Clarity for macOS.

## Prerequisites

### Apple Developer Account
You need an Apple Developer account ($99/year) to distribute apps outside the Mac App Store.

1. Enroll at [developer.apple.com](https://developer.apple.com/programs/)
2. Create a "Developer ID Application" certificate in Xcode or Apple Developer portal
3. Generate an app-specific password for notarization

### Required Tools
- Xcode Command Line Tools: `xcode-select --install`
- Swift 5.9+: Included with Xcode

## Quick Start

```bash
# Build release
make release

# Create unsigned app bundle (for local testing)
make bundle

# Create signed app (requires Developer ID)
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
make sign

# Full distribution with notarization
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export TEAM_ID="XXXXXXXXXX"
make dist
```

## Step-by-Step Guide

### 1. Create Developer ID Certificate

1. Open Xcode > Settings > Accounts
2. Select your team and click "Manage Certificates"
3. Click "+" and select "Developer ID Application"
4. The certificate will be installed in your Keychain

To find your certificate name:
```bash
security find-identity -v -p codesigning | grep "Developer ID"
```

### 2. Create App-Specific Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign In > Security > App-Specific Passwords
3. Click "Generate Password" and label it "Clarity Notarization"
4. Save the generated password securely

### 3. Find Your Team ID

```bash
# List available teams
xcrun altool --list-providers -u "your@email.com" -p "xxxx-xxxx-xxxx-xxxx"
```

Or find it in the Apple Developer portal under Membership.

### 4. Build and Sign

```bash
# Set environment variables
export DEVELOPER_ID="Developer ID Application: Your Name (XXXXXXXXXX)"

# Build and sign
make sign
```

### 5. Notarize

```bash
export APPLE_ID="your@email.com"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export TEAM_ID="XXXXXXXXXX"

make notarize
```

Notarization typically takes 2-5 minutes. The script will wait for completion.

### 6. Create DMG

```bash
make dmg
```

The DMG will be created at `dist/Clarity-1.0.0.dmg`.

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Debug build |
| `make release` | Release build |
| `make test` | Run unit tests |
| `make clean` | Clean build artifacts |
| `make bundle` | Create .app bundle |
| `make sign` | Sign with Developer ID |
| `make notarize` | Notarize with Apple |
| `make dmg` | Create distributable DMG |
| `make install` | Install to /Applications |
| `make uninstall` | Remove from /Applications |
| `make dist` | Full distribution build |

## Troubleshooting

### "Developer ID Application" not found
Ensure the certificate is installed in your Keychain. Check with:
```bash
security find-identity -v -p codesigning
```

### Notarization fails with "Invalid credentials"
1. Verify your Apple ID is correct
2. Ensure the app-specific password is valid
3. Check the Team ID matches your account

### "The signature is invalid"
Run verification to see details:
```bash
codesign --verify --verbose=4 dist/Clarity.app
spctl --assess --verbose dist/Clarity.app
```

### App won't open after installation
Grant Accessibility permission:
1. System Settings > Privacy & Security > Accessibility
2. Add Clarity.app and enable the toggle

## Security Notes

- **Never commit credentials** to version control
- Use environment variables or a secure secrets manager
- The app-specific password is single-use for this app only
- Revoke and regenerate passwords if compromised

## Version Updates

To release a new version:

1. Update version in `Sources/ClarityApp/Info.plist`
2. Update version in `Sources/ClarityDaemon/Info.plist`
3. Update VERSION in `Makefile`
4. Run `make dist`
