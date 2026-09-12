#!/bin/sh
set -eu
mkdir -p downloads
NOTES="$(dirname "$0")/install_notes"
TAGGED_NEW="https://github.com/GerardoRosas-27/olivo-flutter/releases/download/v1.0.0-mobile/Olivo.apk"
LATEST="https://github.com/GerardoRosas-27/olivo-flutter/releases/latest/download/Olivo.apk"
echo Fetching_APK
if ! curl -fL --retry 3 --retry-delay 2 -o downloads/olivo.apk "$TAGGED_NEW"; then
  echo fallback_latest
  curl -fL --retry 3 --retry-delay 2 -o downloads/olivo.apk "$LATEST"
fi
test -s downloads/olivo.apk
ls -lh downloads/olivo.apk
TMP_A=$(mktemp -d)
cp downloads/olivo.apk "$TMP_A/olivo.apk"
cp "$NOTES/INSTALL_ANDROID.txt" "$TMP_A/INSTALL_ANDROID.txt"
(cd "$TMP_A" && zip -q -r /app/downloads/olivo-android.zip olivo.apk INSTALL_ANDROID.txt)
rm -rf "$TMP_A"
ls -lh downloads/olivo-android.zip
TMP_I=$(mktemp -d)
cp "$NOTES/INSTALL_IOS.txt" "$TMP_I/INSTALL_IOS.txt"
(cd "$TMP_I" && zip -q -r /app/downloads/olivo-ios.zip INSTALL_IOS.txt)
rm -rf "$TMP_I"
ls -lh downloads/olivo-ios.zip
