#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building CoinWatch..."
xcodebuild -project CoinWatch.xcodeproj -scheme CoinWatch -configuration Release -derivedDataPath .build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet 2>&1
if [ $? -eq 0 ]; then cp -R .build/Build/Products/Release/CoinWatch.app ~/Desktop/; echo "✅ Done"; open ~/Desktop/CoinWatch.app; else echo "❌ Build failed"; exit 1; fi
