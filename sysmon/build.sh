#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building SysMon..."
xcodebuild -project SysMon.xcodeproj -scheme SysMon -configuration Release -derivedDataPath .build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet 2>&1
if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/SysMon.app ~/Desktop/
    echo "✅ Done — SysMon.app is on your Desktop"
    open ~/Desktop/SysMon.app
else
    echo "❌ Build failed"
    exit 1
fi
