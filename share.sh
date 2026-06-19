#!/bin/zsh
# Share all apps — zips them up to ~/Desktop/Apps/
# Run this, then copy the folder to other Macs or serve via python3 -m http.server

DEST=~/Desktop/Apps
rm -rf "$DEST"
mkdir -p "$DEST"

APPS=(
    ~/Desktop/Stickies.app
    ~/Desktop/NotionLite.app
    ~/Desktop/DeepAgents.app
    ~/Desktop/Dishwasher.app
    ~/Desktop/SysMon.app
    ~/Desktop/GitStreak.app
)

echo "📦 Zipping apps..."
for app in "${APPS[@]}"; do
    if [ -d "$app" ]; then
        name=$(basename "$app" .app)
        zip -rq "$DEST/$name.zip" "$app" -x "*.build*"
        size=$(du -sh "$DEST/$name.zip" | cut -f1)
        echo "  ✅ $name ($size)"
    else
        echo "  ❌ $app not found"
    fi
done

echo ""
echo "📁 Apps zipped to: $DEST"
echo ""
echo "Share options:"
echo "  1. AirDrop: Finder → AirDrop → drag the Apps folder"
echo "  2. HTTP:    cd ~/Desktop && python3 -m http.server 8080"
echo "  3. USB:     cp -R $DEST /Volumes/YOUR_USB/"
echo "  4. SCP:     scp -r $DEST user@other-mac.local:~/Desktop/"
echo ""
echo "On the other Mac: unzip, right-click → Open (first time)"
