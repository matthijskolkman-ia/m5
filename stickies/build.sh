#!/bin/zsh
# Quick-build script for Stickies.app
# Run from the stickies/ project directory

cd "$(dirname "$0")"

echo "🔨 Building Stickies..."
xcodebuild -project Stickies.xcodeproj \
    -scheme Stickies \
    -configuration Release \
    -derivedDataPath .build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1

if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/Stickies.app ~/Desktop/
    echo "✅ Done — Stickies.app is on your Desktop"
    open ~/Desktop/Stickies.app
else
    echo "❌ Build failed"
    exit 1
fi
