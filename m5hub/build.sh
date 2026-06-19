#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building & deploying m5 Hub..."
DEVICE=$(xcrun xctrace list devices 2>&1 | grep -o 'iPhone[^(]*([^)]*' | head -1 | grep -o '[0-9A-F]\{24\}')
if [ -z "$DEVICE" ]; then echo "No iPhone connected"; exit 1; fi

xcodebuild -project M5Hub.xcodeproj -scheme M5Hub -configuration Debug -derivedDataPath /tmp/m5hub-build -sdk iphoneos -destination "id=$DEVICE" -allowProvisioningUpdates DEVELOPMENT_TEAM=69AYY329Y5 -quiet 2>&1

if [ $? -eq 0 ]; then
    echo "Installing..."
    xcrun devicectl device install app --device "$DEVICE" /tmp/m5hub-build/Build/Products/Debug-iphoneos/M5Hub.app 2>&1 | tail -1
    echo "Launching..."
    xcrun devicectl device process launch --device "$DEVICE" com.m5hub.app 2>&1 | tail -1
    echo "✅ m5 Hub on iPhone"
else
    echo "❌ Build failed"
    xcodebuild -project M5Hub.xcodeproj -scheme M5Hub -configuration Debug -derivedDataPath /tmp/m5hub-build -sdk iphoneos -destination "id=$DEVICE" -allowProvisioningUpdates DEVELOPMENT_TEAM=69AYY329Y5 2>&1 | grep "error:" | head -10
    exit 1
fi
