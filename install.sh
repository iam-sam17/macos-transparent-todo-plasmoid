#!/usr/bin/env bash
# macOS Floating Reminders - Automated Installer for KDE Plasma 6
set -e

WIDGET_ID="org.minhaz.macos.transparent.todo"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"
ALT_DIR="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.macosreminders"

echo "=========================================================="
echo "  Installing macOS Floating Reminders for KDE Plasma 6... "
echo "  Version: 2.0.0 (Native Subtasks, Categories, Settings)  "
echo "=========================================================="

mkdir -p "$HOME/.local/share/plasma/plasmoids"

# 1. Clean prior conflicting installations completely
rm -rf "$TARGET_DIR" "$ALT_DIR"

# 2. Check for Development Symlink Mode
if [[ "$1" == "--dev" || "$1" == "-s" ]]; then
    echo "⚡ Linking source directory in development symlink mode..."
    ln -sfn "$SOURCE_DIR" "$TARGET_DIR"
else
    echo "📦 Deploying production package files..."
    mkdir -p "$TARGET_DIR"
    cp -r "$SOURCE_DIR/metadata.json" "$TARGET_DIR/"
    cp -r "$SOURCE_DIR/contents" "$TARGET_DIR/"
    [[ -f "$SOURCE_DIR/LICENSE" ]] && cp "$SOURCE_DIR/LICENSE" "$TARGET_DIR/"
    [[ -f "$SOURCE_DIR/README.md" ]] && cp "$SOURCE_DIR/README.md" "$TARGET_DIR/"
fi

echo "✓ Successfully deployed to: $TARGET_DIR"

# 3. Reload Plasma shell to reflect changes immediately
echo "🔄 Refreshing Plasma Shell..."
if command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
fi

echo ""
echo "🎉 macOS Floating Reminders v2.0.0 successfully installed!"
echo "💡 If changes don't appear immediately, run: systemctl --user restart plasma-plasmashell.service"
