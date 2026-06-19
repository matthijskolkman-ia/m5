#!/bin/zsh
cd "$(dirname "$0")"
echo "🔨 Building DeepAgents..."
xcodebuild -project DeepAgents.xcodeproj \
    -scheme DeepAgents -configuration Release \
    -derivedDataPath .build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1
if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/DeepAgents.app ~/Desktop/
    echo "✅ Done — DeepAgents.app is on your Desktop"
    open ~/Desktop/DeepAgents.app
else
    echo "❌ Build failed"
    exit 1
fi
