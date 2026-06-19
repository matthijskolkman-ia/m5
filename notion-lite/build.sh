#!/bin/zsh
cd "$(dirname "$0")"

echo "🔨 Building NotionLite..."
xcodebuild -project NotionLite.xcodeproj \
    -scheme NotionLite \
    -configuration Release \
    -derivedDataPath .build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1

if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/NotionLite.app ~/Desktop/
    echo "✅ Done — NotionLite.app is on your Desktop"
    open ~/Desktop/NotionLite.app
else
    echo "❌ Build failed"
    exit 1
fi
