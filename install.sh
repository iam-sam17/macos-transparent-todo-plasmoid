#!/usr/bin/env bash
set -e

WIDGET_ID="org.minhaz.macos.transparent.todo"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"

echo "=========================================================="
echo "  Installing macOS Floating To-Do for KDE Plasma 6...     "
echo "=========================================================="

mkdir -p "$HOME/.local/share/plasma/plasmoids"

# Clean old installation completely (both directory and symlink)
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -r "$SOURCE_DIR"/* "$TARGET_DIR"/

echo "✓ Successfully deployed to: $TARGET_DIR"

# Clear QML/Plasma cache if possible
if command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
fi

echo ""
echo "🎉 উইজেট v1.0.2 সফলভাবে ইনস্টল ও আপডেট সম্পন্ন!"
