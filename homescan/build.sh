#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building HomeScan..."
xcodebuild -project HomeScan.xcodeproj -scheme HomeScan -configuration Release -derivedDataPath .build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet 2>&1
if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/HomeScan.app ~/Desktop/
    echo "✅ Done — HomeScan.app is on your Desktop"
    open ~/Desktop/HomeScan.app
else
    echo "❌ Build failed"
    exit 1
fi
