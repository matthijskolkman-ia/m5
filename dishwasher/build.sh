#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building Dishwasher..."
xcodebuild -project Dishwasher.xcodeproj \
    -scheme Dishwasher -configuration Release \
    -derivedDataPath .build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1
if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/Dishwasher.app ~/Desktop/
    echo "✅ Done — Dishwasher.app is on your Desktop"
    open ~/Desktop/Dishwasher.app
else
    echo "❌ Build failed"
    exit 1
fi
