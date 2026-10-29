#!/bin/bash
# Первая настройка на маке: ядро Xray + генерация .xcodeproj.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v xcodegen >/dev/null || { echo "Нет XcodeGen: brew install xcodegen"; exit 1; }

[ -d Vendor/LibXray.xcframework ] || ./scripts/build-libxray.sh
xcodegen generate
echo "Открыть: open Umbra.xcodeproj"
