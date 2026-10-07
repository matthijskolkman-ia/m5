#!/bin/zsh
cd "$(dirname "$0")"

echo "📁 Generating Xcode project..."
xcodegen generate --spec project.yml --quiet

echo "🔨 Building CardVault iOS..."
xcodebuild -project CardVaultIOS.xcodeproj \
    -scheme CardVaultIOS \
    -configuration Release \
    -derivedDataPath /tmp/cardvault-ios-build \
    -destination 'platform=iOS,id=00008150-001845AC21DA401C' \
    -quiet 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Done — CardVault installed on iPhone"
else
    echo "❌ Build failed"
    exit 1
fi
