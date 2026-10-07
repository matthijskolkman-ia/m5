#!/bin/zsh
cd "$(dirname "$0")"

echo "📁 Generating Xcode project..."
xcodegen generate --spec project.yml --quiet

echo "🔨 Building FolderViewer..."
xcodebuild -project FolderViewer.xcodeproj \
    -scheme FolderViewer \
    -configuration Release \
    -derivedDataPath .build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1

if [ $? -eq 0 ]; then
    cp -R .build/Build/Products/Release/FolderViewer.app ~/Desktop/
    echo "✅ Done — FolderViewer.app is on your Desktop"
    open ~/Desktop/FolderViewer.app
else
    echo "❌ Build failed"
    exit 1
fi
