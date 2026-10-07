#!/bin/zsh
cd "$(dirname "$0")"

echo "📁 Generating Xcode project..."
xcodegen generate --spec project.yml --quiet

echo "🔨 Building CardVault..."
xcodebuild -project CardVault.xcodeproj \
    -scheme CardVault \
    -configuration Release \
    -derivedDataPath .build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1

if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/CardVault.app ~/Desktop/
    echo "✅ Done — CardVault.app is on your Desktop"
    open ~/Desktop/CardVault.app
else
    echo "❌ Build failed"
    exit 1
fi
