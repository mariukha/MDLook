#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

command -v swiftc >/dev/null || { echo "Command Line Tools required: xcode-select --install"; exit 1; }

SDK=$(xcrun --sdk macosx --show-sdk-path)
TARGET="$(uname -m)-apple-macos13.0"
APP=build/MDLook.app
APPEX="$APP/Contents/PlugIns/MDLookPreview.appex"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"

echo "Building extension..."
swiftc -O -sdk "$SDK" -target "$TARGET" \
  -module-name MDLookPreview -parse-as-library -application-extension \
  -framework Cocoa -framework Quartz -framework JavaScriptCore \
  -Xlinker -e -Xlinker _NSExtensionMain \
  Preview/PreviewProvider.swift \
  -o "$APPEX/Contents/MacOS/MDLookPreview"

cp Preview/marked.js Preview/style.css Preview/marked-LICENSE.txt "$APPEX/Contents/Resources/"

cat > "$APPEX/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>MDLook Preview</string>
  <key>CFBundleExecutable</key><string>MDLookPreview</string>
  <key>CFBundleIdentifier</key><string>com.mariukha.MDLook.Preview</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>MDLookPreview</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.quicklook.preview</string>
    <key>NSExtensionPrincipalClass</key><string>MDLookPreview.PreviewProvider</string>
    <key>NSExtensionAttributes</key><dict>
      <key>QLIsDataBasedPreview</key><true/>
      <key>QLSupportsSearchableItems</key><false/>
      <key>QLSupportedContentTypes</key><array>
        <string>net.daringfireball.markdown</string>
        <string>public.markdown</string>
      </array>
    </dict>
  </dict>
</dict></plist>
PLIST

echo "Building app..."
swiftc -O -sdk "$SDK" -target "$TARGET" \
  -module-name MDLook -parse-as-library \
    App/MDLookApp.swift \
  -o "$APP/Contents/MacOS/MDLook"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>MDLook</string>
  <key>CFBundleExecutable</key><string>MDLook</string>
  <key>CFBundleIdentifier</key><string>com.mariukha.MDLook</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>MDLook</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>UTImportedTypeDeclarations</key><array><dict>
    <key>UTTypeIdentifier</key><string>net.daringfireball.markdown</string>
    <key>UTTypeDescription</key><string>Markdown Document</string>
    <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
    <key>UTTypeTagSpecification</key><dict>
      <key>public.filename-extension</key><array>
        <string>md</string><string>markdown</string><string>mdown</string><string>mkd</string><string>mkdn</string>
      </array>
      <key>public.mime-type</key><array><string>text/markdown</string></array>
    </dict>
  </dict></array>
</dict></plist>
PLIST

cat > build/sandbox.entitlements <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.files.user-selected.read-only</key><true/>
</dict></plist>
PLIST

echo "Signing (ad hoc)..."
codesign -f -s - --entitlements build/sandbox.entitlements "$APPEX"
codesign -f -s - --entitlements build/sandbox.entitlements "$APP"

echo "Installing to /Applications..."
rm -rf /Applications/MDLook.app
cp -R "$APP" /Applications/
xattr -dr com.apple.quarantine /Applications/MDLook.app 2>/dev/null || true

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/MDLook.app
open -g /Applications/MDLook.app
sleep 2
pluginkit -a /Applications/MDLook.app/Contents/PlugIns/MDLookPreview.appex 2>/dev/null || true
pluginkit -e use -i com.mariukha.MDLook.Preview 2>/dev/null || true
qlmanage -r >/dev/null 2>&1
qlmanage -r cache >/dev/null 2>&1

echo
echo "Done. Select a .md file in Finder and press Space."
echo "Check: pluginkit -mv -p com.apple.quicklook.preview | grep -i mdlook"
