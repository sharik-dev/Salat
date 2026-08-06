#!/bin/zsh
# Archive de release → IPA App Store.
#
#   scripts/build_ios.sh
#
# Le pendant Xcode de `godotGame/kit/template/scripts/build_ios.sh` : ici pas
# d'export Godot à corriger, mais le projet est **généré** (voir CLAUDE.md), donc
# on relance `xcodegen` d'abord — sinon on archiverait un `.xcodeproj` en retard
# d'un fichier sans que rien ne le signale.
set -e
cd "$(dirname "$0")/.."

OUT="build/ios"
SCHEME="Salat"

echo "── 1/3 Projet Xcode ──"
xcodegen generate

echo "── 2/3 Archive ──"
rm -rf "$OUT/$SCHEME.xcarchive"
# `-allowProvisioningUpdates` a besoin de la clé ASC : c'est lui qui enregistre
# au passage l'App Group `group.com.salat` et régénère les profils des DEUX
# cibles (l'app et son widget). Sans la clé, il ouvrirait une invite de mot de
# passe Apple au milieu d'une chaîne automatisée.
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -sdk iphoneos -configuration Release -destination generic/platform=iOS \
  archive -archivePath "$OUT/$SCHEME.xcarchive" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_P8_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -quiet

echo "── 3/3 Export IPA ──"
mkdir -p "$OUT"
cat > "$OUT/export_options.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$(sed -n 's/.*DEVELOPMENT_TEAM: "\(.*\)"/\1/p' project.yml)</string>
  <key>uploadSymbols</key><true/>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$OUT/$SCHEME.xcarchive" \
  -exportOptionsPlist "$OUT/export_options.plist" \
  -exportPath "$OUT" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_P8_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -quiet

echo "✓ IPA prêt : $OUT/$SCHEME.ipa"
