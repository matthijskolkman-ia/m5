#!/bin/bash
# Song Vault iOS — Project Generator
# Creates the Xcode project from project.yml using XcodeGen

set -e

echo "🛠  Song Vault iOS Project Generator"
echo "===================================="
echo ""

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
fi

# Generate the project
echo "🔨 Generating Xcode project..."
cd "$(dirname "$0")"
xcodegen generate

echo ""
echo "✅ Done! Open SongVault.xcodeproj in Xcode."
echo ""
echo "📱 Next steps:"
echo "   1. Open SongVault.xcodeproj"
echo "   2. Select 'SongVault' target → Signing & Capabilities"
echo "   3. Choose your Team (Apple Developer account)"
echo "   4. In Sources/Services/APIService.swift, change serverHost to your Mac's IP"
echo "   5. Plug in your iPhone 8"
echo "   6. Select it as the run destination (top left in Xcode)"
echo "   7. Press ⌘R to build & run!"
echo ""
echo "🔍 Find your Mac's IP: System Settings → Network → Wi-Fi → Details"
echo "   It looks like: 192.168.x.x"
echo ""
echo "⚠️  Make sure the Flask server is running on your Mac:"
echo "   cd ../song-vault && python3 app.py"
