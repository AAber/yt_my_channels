#!/bin/bash
set -euo pipefail

IOS_DIR=ios

# ✅ Read version from pubspec.yaml (source of truth)
CURRENT=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)
BUILD_NUMBER=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f2)

echo "📦 Current version: $CURRENT"
echo "🔢 Current build number: $BUILD_NUMBER"

# ✅ Parse MAJOR.MINOR.PATCH
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

if ! [[ "$MAJOR" =~ ^[0-9]+$ ]] || \
   ! [[ "$MINOR" =~ ^[0-9]+$ ]] || \
   ! [[ "$PATCH" =~ ^[0-9]+$ ]]; then
    echo "❌ Could not parse version '$CURRENT' as MAJOR.MINOR.PATCH"
    exit 1
fi

echo "✅ Parsed: MAJOR=$MAJOR MINOR=$MINOR PATCH=$PATCH"

# ✅ Write version into Xcode project using agvtool
cd "$IOS_DIR"

echo "🔄 Setting marketing version to $CURRENT..."
xcrun agvtool new-marketing-version "$CURRENT"

echo "🔄 Setting build number to $BUILD_NUMBER..."
xcrun agvtool new-version -all "$BUILD_NUMBER"

echo "✅ Xcode project updated to version $CURRENT ($BUILD_NUMBER)"
