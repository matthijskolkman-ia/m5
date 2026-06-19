#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building GitSync..."
xcodebuild -project GitSync.xcodeproj -scheme GitSync -configuration Release -derivedDataPath .build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet 2>&1
if [ $? -eq 0 ]; then cp -R .build/Build/Products/Release/GitSync.app ~/Desktop/; echo "✅ Done — GitSync.app is on your Desktop"; open ~/Desktop/GitSync.app; else echo "❌ Build failed"; exit 1; fi
