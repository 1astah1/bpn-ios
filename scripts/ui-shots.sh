#!/bin/bash
# Прогон UI-теста на маке и выгрузка скриншотов: scripts/ui-shots.sh <ссылка подписки> [симулятор]
# Скриншоты — в shots/ui/<имя>.png.
set -euo pipefail
cd "$(dirname "$0")/.."
SUB="$1"
DEVICE="${2:-iPhone 17 Pro}"
ID=$(xcrun simctl list devices available -j | python3 -c "import json,sys; n=sys.argv[1]; print(next(d['udid'] for r in json.load(sys.stdin)['devices'].values() for d in r if d['name']==n))" "$DEVICE")
# Чистый симулятор: без чужих окон (Safari и т.п.) поверх приложения на скриншотах.
xcrun simctl shutdown "$ID" 2>/dev/null || true
xcrun simctl erase "$ID"
xcrun simctl boot "$ID" 2>/dev/null || true
xcrun simctl bootstatus "$ID" -b >/dev/null
xcrun simctl uninstall "$ID" "$(grep -E '^BUNDLE_ID_PREFIX' Config/Base.xcconfig | awk '{print $3}')" || true
rm -rf build/ui.xcresult shots/ui && mkdir -p shots/ui
TEST_RUNNER_SUBSCRIPTION_URL="$SUB" xcodebuild test -project Umbra.xcodeproj -scheme App -destination "id=$ID" \
    -derivedDataPath build/dd -resultBundlePath build/ui.xcresult 2>&1 \
    | grep -E "error:|failed|passed|TEST (SUCCEEDED|FAILED)" || true
xcrun xcresulttool export attachments --path build/ui.xcresult --output-path shots/ui >/dev/null
python3 - <<'PY'
import json, os
os.chdir("shots/ui")
for test in json.load(open("manifest.json")):
    for a in test.get("attachments", []):
        name = (a.get("suggestedHumanReadableName") or a["exportedFileName"]).split("_")[0]
        os.rename(a["exportedFileName"], name + ".png")
print("\n".join(sorted(f for f in os.listdir(".") if f.endswith(".png"))))
PY
