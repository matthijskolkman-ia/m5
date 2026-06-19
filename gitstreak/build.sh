#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building GitStreak..."
xcodebuild -project GitStreak.xcodeproj -scheme GitStreak -configuration Release -derivedDataPath .build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet 2>&1
if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/GitStreak.app ~/Desktop/
    echo "✅ Done — GitStreak.app is on your Desktop"
    open ~/Desktop/GitStreak.app
else
    echo "❌ Build failed"
    exit 1
fi
