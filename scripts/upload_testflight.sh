#!/bin/zsh
set -e
cd "$(dirname "$0")/.."

source ~/.config/ios-testflight-cicd/config.env
# Même slug que `build_ios.sh`, et pour la même raison — rien du jeu n'est écrit
# dans ce fichier, il part tel quel dans le kit.
IPA="build/ios/$(basename "$PWD").ipa"

mkdir -p ~/.appstoreconnect/private_keys
cp -f "$ASC_KEY_P8_PATH" ~/.appstoreconnect/private_keys/

echo "── Validation ──"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "── Envoi ──"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
