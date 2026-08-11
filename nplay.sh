#!/bin/bash

# Play Store Build Script
# This script builds the app bundle and prepares it for Play Store upload

set -e  # Exit on any error

echo "Update the version and the script will increment the build"
sleep 3
vi pubspec.yaml
echo Ready to go? Enter to continue Ctrl-C to cancel...

# Configuration
# Auto-detect current version from pubspec.yaml
current_full_version=$(grep "version:" pubspec.yaml | sed 's/version: //')
version_base=$(echo $current_full_version | cut -d'+' -f1)
build_number=$(echo $current_full_version | cut -d'+' -f2)
next_build_number=$((build_number + 1))
next_full_version="$version_base+$next_build_number"

BUILD_DIR="~/yt_my_channels-appbundle"
KEYSTORE_SOURCE="~/_zync/israel/upload-keystore.jks"
KEY_PROPS_SOURCE="~/_zync/israel/key.properties"

echo "🚀 Starting Play Store build process"
echo "Current version: $current_full_version"
echo "Next version: $next_full_version"
echo ""

# Verify Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Verify sed is available
if ! command -v sed &> /dev/null; then
    echo "❌ sed not found. Please install sed first."
    exit 1
fi

echo "✅ Prerequisites check passed"
read -p "Press Enter to continue with version update..."

# Update version in pubspec.yaml
echo "📝 Updating version in pubspec.yaml..."
sed -i "s/version: $current_full_version/version: $next_full_version/" pubspec.yaml

# Verify version was updated
new_version=$(grep "version:" pubspec.yaml | awk '{print $2}')
echo "✅ Version updated to: $new_version"

read -p "Press Enter to continue with keystore setup..."

# Copy keystore and key properties from secure location
echo "🔐 Setting up signing credentials..."

# Expand tilde in paths
KEYSTORE_SOURCE_EXPANDED=$(eval echo $KEYSTORE_SOURCE)
KEY_PROPS_SOURCE_EXPANDED=$(eval echo $KEY_PROPS_SOURCE)

if [ ! -f "$KEYSTORE_SOURCE_EXPANDED" ]; then
    echo "❌ Keystore not found at: $KEYSTORE_SOURCE_EXPANDED"
    exit 1
fi

if [ ! -f "$KEY_PROPS_SOURCE_EXPANDED" ]; then
    echo "❌ Key properties not found at: $KEY_PROPS_SOURCE_EXPANDED"
    exit 1
fi

# Copy signing files
# Copy both to android/app/ to ensure relative paths work correctly
cp "$KEYSTORE_SOURCE_EXPANDED" android/app/upload-keystore.jks
cp "$KEY_PROPS_SOURCE_EXPANDED" android/app/key.properties

# Force storeFile property to point to the local file we just copied
# This prevents path issues if the source key.properties uses specific relative paths
if grep -q "storeFile" android/app/key.properties; then
    sed -i 's|storeFile=.*|storeFile=upload-keystore.jks|' android/app/key.properties
else
    echo "storeFile=upload-keystore.jks" >> android/app/key.properties
fi

echo "✅ Signing credentials copied successfully"

read -p "Press Enter to continue with build..."

echo Get deps...
flutter pub get
cd ios
pod install
if [ $? -ne 0 ]; then
    echo "❌ Pod install failed"
    # Clean up sensitive files before exit
    rm -f android/app/upload-keystore.jks
    rm -f android/app/key.properties
    exit 1
fi
cd ..

# Build the app bundle
echo "🔨 Building release app bundle..."
flutter build appbundle --release

if [ $? -ne 0 ]; then
    echo "❌ Flutter build appbundle failed"
    # Clean up sensitive files before exit
    rm -f android/app/upload-keystore.jks
    rm -f android/app/key.properties
    exit 1
fi

echo "✅ App bundle built successfully"

# Create output directory and copy app bundle
echo "📦 Copying app bundle to output directory..."
BUILD_DIR_EXPANDED=$(eval echo $BUILD_DIR)
mkdir -p "$BUILD_DIR_EXPANDED"

# Copy with version tag in filename
cp build/app/outputs/bundle/release/app-release.aab "$BUILD_DIR_EXPANDED/app-release-$new_version.aab"

if [ $? -ne 0 ]; then
    echo "❌ Failed to copy app bundle"
    # Clean up sensitive files before exit
    rm -f android/app/upload-keystore.jks
    rm -f android/app/key.properties
    exit 1
fi

echo "✅ App bundle copied to: $BUILD_DIR_EXPANDED/app-release-$new_version.aab"

echo Run bump-ios.sh
read a

# Security cleanup - Remove sensitive files
echo "🔒 Cleaning up sensitive files for security..."
rm -f android/app/upload-keystore.jks
rm -f android/app/key.properties

echo "✅ Sensitive files removed"

# Verify files are removed
if [ -f "android/app/upload-keystore.jks" ] || [ -f "android/app/key.properties" ]; then
    echo "⚠️  Warning: Some sensitive files may still exist"
else
    echo "✅ All sensitive files successfully removed"
fi

echo Create a TAG!!!
echo Enter to continue Cntl-C to abort!!
read a

# Git operations
echo "📝 Committing version changes..."
git add -A
git commit -m "bump version to $new_version"
git tag "$new_version"
git push origin "$new_version"
git push

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 All done B\"H!"
    echo "📱 App bundle ready at: $BUILD_DIR_EXPANDED/app-release-$new_version.aab"
    echo "🏪 Ready to upload to Google Play Console"
    echo "🔖 Version tagged and pushed: $new_version"
else
    echo "❌ Git operations failed"
    exit 1
fi
