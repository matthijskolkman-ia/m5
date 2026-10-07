#!/bin/bash
# Install the "Ping iPhone" shortcut for Find My Trigger

SHORTCUTS_DIR="$HOME/Library/Shortcuts"
mkdir -p "$SHORTCUTS_DIR"

# Create the shortcut plist
cat > /tmp/ping_iphone.shortcut << 'SHORTCUT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>WFWorkflowActions</key>
    <array>
        <dict>
            <key>WFWorkflowActionIdentifier</key>
            <string>is.workflow.actions.finddevices</string>
            <key>WFWorkflowActionParameters</key>
            <dict/>
        </dict>
        <dict>
            <key>WFWorkflowActionIdentifier</key>
            <string>is.workflow.actions.play sound</string>
            <key>WFWorkflowActionParameters</key>
            <dict/>
        </dict>
    </array>
    <key>WFWorkflowClientVersion</key>
    <string>1680.3.4</string>
    <key>WFWorkflowIcon</key>
    <dict>
        <key>WFWorkflowIconGlyphNumber</key>
        <integer>59653</integer>
    </dict>
    <key>WFWorkflowImportQuestions</key>
    <array/>
    <key>WFWorkflowInputContentItemClasses</key>
    <array/>
    <key>WFWorkflowMinimumClientVersion</key>
    <integer>900</integer>
    <key>WFWorkflowName</key>
    <string>Ping iPhone</string>
    <key>WFWorkflowTypes</key>
    <array>
        <string>WatchKit</string>
        <string>NCWidget</string>
    </array>
</dict>
</plist>
SHORTCUT

echo "Installed Ping iPhone shortcut"
