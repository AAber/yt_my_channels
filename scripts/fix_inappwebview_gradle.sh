#!/bin/bash
# Patches flutter_inappwebview_android build.gradle to replace the deprecated
# proguard-android.txt with proguard-android-optimize.txt (required for AGP 9+).

FILE=$(find ~/.pub-cache/hosted/pub.dev -path "*/flutter_inappwebview_android-*/android/build.gradle" | head -1)

if [ -z "$FILE" ]; then
  echo "❌ flutter_inappwebview_android not found in pub cache. Run 'flutter pub get' first."
  exit 1
fi

if grep -q "proguard-android-optimize.txt" "$FILE"; then
  echo "✅ Already patched: $FILE"
  exit 0
fi

sed -i '' "s/getDefaultProguardFile('proguard-android.txt')/getDefaultProguardFile('proguard-android-optimize.txt')/g" "$FILE"
echo "✅ Patched: $FILE"
