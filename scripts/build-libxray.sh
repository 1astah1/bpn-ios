#!/bin/bash
# Собирает Vendor/LibXray.xcframework (ядро Xray, MIT/MPL) только под iOS: устройство + симулятор arm64.
# То же, что `python3 build/main.py apple go` в libXray, но без macOS/tvOS — им нужны лишние SDK.
# Запускать на маке: нужен Xcode и Go (brew install go; нужную версию Go подтянет сам).
set -euo pipefail

LIBXRAY_TAG="v26.10.21"   # v26.10.10 и v26.10.17 отозваны — не брать
MIN_IOS="17.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Vendor/LibXray.xcframework"
WORK="${TMPDIR:-/tmp}/libxray-$LIBXRAY_TAG"

command -v go >/dev/null || { echo "Нет Go: brew install go"; exit 1; }
command -v xcrun >/dev/null || { echo "Нет Xcode"; exit 1; }

if [ ! -d "$WORK/.git" ]; then
    rm -rf "$WORK"
    git clone --quiet --depth 1 --branch "$LIBXRAY_TAG" https://github.com/XTLS/libXray.git "$WORK"
fi
cd "$WORK"

build_slice() {
    local sdk="$1" go_arch="$2" apple_arch="$3"
    local sdk_path flags
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
    flags="-isysroot $sdk_path -m${sdk}-version-min=$MIN_IOS -arch $apple_arch"
    mkdir -p "out/$sdk"
    echo "→ $sdk $apple_arch"
    env GOOS=ios GOARCH="$go_arch" GOFLAGS="-tags=ios" CGO_ENABLED=1 \
        CC="xcrun --sdk $sdk --toolchain $sdk clang" \
        CXX="xcrun --sdk $sdk --toolchain $sdk clang++" \
        CGO_CFLAGS="$flags" CGO_CXXFLAGS="$flags" \
        CGO_LDFLAGS="$flags -Wl,-Bsymbolic-functions" \
        DARWIN_SDK="$sdk" \
        go build -trimpath -ldflags "-s -w -buildid=" -buildmode=c-archive \
            -o "out/$sdk/libXray.a" ./cgo_bridge
}

build_slice iphoneos arm64 arm64
build_slice iphonesimulator arm64 arm64

rm -rf include && mkdir include
cp out/iphoneos/libXray.h include/
cp build/template/module.modulemap include/

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
xcodebuild -create-xcframework \
    -library out/iphoneos/libXray.a -headers include \
    -library out/iphonesimulator/libXray.a -headers include \
    -output "$OUT"

echo "Готово: $OUT ($LIBXRAY_TAG)"
