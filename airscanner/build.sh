#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building AirScanner..."
xcodebuild -project AirScanner.xcodeproj -scheme AirScanner -configuration Release -derivedDataPath .build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet 2>&1
if [ $? -eq 0 ]; then cp -R .build/Build/Products/Release/AirScanner.app ~/Desktop/; echo "✅ Done"; open ~/Desktop/AirScanner.app; else echo "❌ Build failed"; exit 1; fi
