#!/bin/zsh
# store_shots.sh : captures brutes de l'App Store, produites par l'app elle-même.
# Lance chaque écran dans chaque langue de la fiche sur le simulateur booté
# (iPhone 17e : même rapport d'écran que le 6,9", et le moins gourmand).
#
#   tools/store_shots.sh [nom …]         # noms = sous-ensemble ; STORE_LANGS="ar" pour une langue
#   → fastlane/screenshots_raw/<langue>/<nom>.png, puis :
#   python3 Design/screenshots/make-design.py && shotsmith Design/screenshots/design.json --out fastlane/screenshots --fastlane
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); cd "$HERE"
U=${STORE_SIM_UDID:-E0390F22-8C3E-45A8-AE28-2B9A3F91CC70}
APP=build/dd/Build/Products/Debug-iphonesimulator/Salat.app
COMMON=(-hasSeenOnboarding YES -alwaysShowOnboarding NO -debugAdsNoConsent 1 -premium 1)

typeset -A SHOTS WAITS
SHOTS=(
  learn     "-demoProgress 1"
  step      "-demoProgress 1 -openStep fatiha"
  listen    "-learnAll 1 -startTab practice -openTool vocal -openStep fatiha -recite 1"
  quran     "-startTab quran -quranSurah 2 -quranVerse 255 -quranMuted 1"
  drill     "-learnAll 1 -startTab practice -openTool drill -drillVerdict right"
  fade      "-learnAll 1 -startTab practice -openTool fade -openStep fatiha -fadeLevel 2"
  widget    "-demoProgress 1 -startTab practice -openTool widget"
  progress  "-demoProgress 1 -openAnalytics 1"
  hub       "-learnAll 1 -startTab practice"
)
WAITS=(listen 9)
NAMES=(${@:-${(k)SHOTS}})
xcrun simctl install $U $APP
xcrun simctl status_bar $U override --time "09:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
for lang in ${=STORE_LANGS:-en fr ar}; do
  mkdir -p fastlane/screenshots_raw/$lang
  for n in $NAMES; do
    args=(${(z)SHOTS[$n]})
    xcrun simctl terminate $U com.salat >/dev/null 2>&1 || true
    xcrun simctl launch $U com.salat -AppleLanguages "($lang)" $COMMON $args >/dev/null
    sleep ${WAITS[$n]:-6}
    xcrun simctl io $U screenshot fastlane/screenshots_raw/$lang/$n.png >/dev/null 2>&1
    echo "$lang/$n"
  done
done
