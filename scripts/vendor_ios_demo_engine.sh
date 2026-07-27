#!/usr/bin/env bash
#
# Vendors the official PaddleOCR iOS demo's OCR Engine Swift sources +
# the Clipper1 third-party C++ lib into this plugin's `ios/Classes/` so the
# Flutter iOS plugin can build on-device OCR using the same pre/post-processing
# as upstream. This is a maintainer-only upgrade tool:
#
#   bash scripts/vendor_ios_demo_engine.sh
#
# The vendored output under `ios/Classes/` IS committed to the repo (same policy
# as the Android `android/ppocr-sdk/` source vendor) so builds are reproducible
# without network access. To upgrade, edit `PADDLE_OCR_REF` below, re-run the
# script, and diff the changes — the README provenance header records the pin.
#
# Files vendored (subset of deploy/ios_demo/PaddleOCRDemo/):
#   Engine/         - all 22 Swift + ObjC++ bridge files (pre/post-processing, ORT sessions)
#   ThirdParty/Clipper1/  - poly offset C++ (Boost Software License 1.0; see its LICENSE)
# Files NOT vendored (SwiftUI UI / ViewModels / Resources / Tests app-level only):
#   App/ Views/ ViewModels/ Resources/ Supporting/
#
# Re-runnable: existing ios/Classes/Engine is removed and replaced on each run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_DIR="$PLUGIN_DIR/ios/Classes"

# A commit SHA is required for reproducible upgrades.
PADDLE_OCR_REF="${PADDLE_OCR_REF:-2661c7c0ef5c613e8f93c6e93b2e052399f0f854}"

REPO="https://github.com/PaddlePaddle/PaddleOCR.git"
BASE="deploy/ios_demo/PaddleOCRDemo"

echo "==> Vending PaddleOCR iOS demo Engine from ref=$PADDLE_OCR_REF"

# Resolve the exact commit SHA for the provenance header (works for both
# branches and SHA inputs).
PIN_SHA="$(git ls-remote "$REPO" "$PADDLE_OCR_REF" | awk '{print $1}')"
if [ -z "$PIN_SHA" ]; then
  # If the ref was already a SHA, ls-remote returns empty; fall back to ref itself.
  PIN_SHA="$PADDLE_OCR_REF"
fi
echo "    resolved SHA: $PIN_SHA"

WORK="$DEST_DIR/.vendor_work"
rm -rf "$WORK"
mkdir -p "$WORK"

echo "==> Sparse-checkout of $BASE/{Engine,ThirdParty/Clipper1}"
git clone --no-checkout --depth 1 --filter=blob:none \
  -b "$PADDLE_OCR_REF" "$REPO" "$WORK/src" 2>/dev/null || \
  git clone --no-checkout --filter=blob:none \
    "$REPO" "$WORK/src"

# If we got branch clone of detached depth, fetch the exact ref.
git -C "$WORK/src" checkout "$PADDLE_OCR_REF" 2>/dev/null || true

cd "$WORK/src"
git sparse-checkout init --cone
git sparse-checkout set "$BASE/Engine" "$BASE/ThirdParty/Clipper1"
git checkout -- "$BASE/Engine" "$BASE/ThirdParty/Clipper1"

cd - >/dev/null

echo "==> Replacing $DEST_DIR/{Engine,ThirdParty}"
rm -rf "$DEST_DIR/Engine" "$DEST_DIR/ThirdParty"
mkdir -p "$DEST_DIR"
mv "$WORK/src/$BASE/Engine"        "$DEST_DIR/Engine"
mv "$WORK/src/$BASE/ThirdParty"    "$DEST_DIR/ThirdParty"
rm -rf "$WORK"

# PATCH STEP — overwrite vendored ModelConfig.swift with our Flutter-aware fork.
# ios/Patches/ModelConfig.swift is committed alongside this script and is the
# canonical paddle_ocr_native local modification. Upgrade workflow: when you re-vendor after
# bumping PADDLE_OCR_REF, this step auto-applies the fork; re-diff the new
# upstream ModelConfig.swift against our fork for any new semantics to fold in.
PATCH_SRC="$PLUGIN_DIR/ios/Patches/ModelConfig.swift"
VENDORED="$DEST_DIR/Engine/ModelConfig.swift"
if [ -f "$PATCH_SRC" ] && [ -f "$VENDORED" ]; then
  echo "==> Applying paddle_ocr_native ModelConfig fork ($PATCH_SRC) -> $VENDORED"
  cp -f "$PATCH_SRC" "$VENDORED"
else
  echo "!! WARNING: missing $PATCH_SRC or vendored $VENDORED — fork not applied"
  echo "    iOS build will fail unless ModelConfig.swift is patched manually."
fi

# PATCH STEP — apply remaining small in-place patches to the vendored Engine
# Swift sources (adds `import onnxruntime_objc` to ORTSessionManager.swift for
# pod-target module resolution; removes a trailing comma in
# OCRParameterResolver.swift that newer Swift parsers reject). Idempotent; safe
# to re-run. See scripts/apply_ios_engine_patches.sh header for upgrade notes.
PATCH_SCRIPT="$PLUGIN_DIR/scripts/apply_ios_engine_patches.sh"
if [ -x "$PATCH_SCRIPT" ]; then
  echo "==> Applying paddle_ocr_native in-place engine patches via $PATCH_SCRIPT"
  "$PATCH_SCRIPT"
else
  echo "!! WARNING: $PATCH_SCRIPT not executable — vendored Swift may fail to build"
fi

# PaddleOcrNativePlugin.swift is local (the Flutter bridge), not vendored.
PROVENANCE="$DEST_DIR/UPSTREAM.md"
cat > "$PROVENANCE" <<EOF
# Vendored from PaddleOCR deploy/ios_demo

Upstream repository: https://github.com/PaddlePaddle/PaddleOCR
Path prefix:         deploy/ios_demo/PaddleOCRDemo/
Pinned ref:          $PADDLE_OCR_REF
Resolved SHA:        $PIN_SHA
Date vendored:       $(date -u +'%Y-%m-%dT%H:%M:%SZ')

## Scope

Only \`Engine/\` (Swift + ObjC++ bridge sources) and \`ThirdParty/Clipper1/\`
(C++ polygon offset, Boost Software License 1.0) are vendored. SwiftUI views /
view-models / sample resources / unit tests of the official demo are NOT vendored
because they are app-shell concerns that belong to the PaddleOcrDemo sample,
not the OCR engine itself.

## Local additions (not part of upstream)

- \`PaddleOcrNativePlugin.swift\` — Flutter MethodChannel bridge to \`OCREngine\`,
  mirroring the wire format of \`android/src/main/kotlin/.../PaddleOcrNativePlugin.kt\`.

## Upgrade procedure

1. Edit \`PADDLE_OCR_REF\` in \`scripts/vendor_ios_demo_engine.sh\` to the new
   ref (commit SHA recommended).
2. Rerun the script.
3. \`git diff ios/Classes/Engine\` to inspect upstream changes; resolve any
   bridging incompatibilities in \`PaddleOcrNativePlugin.swift\`.
4. Update this file with the new SHA + date.
EOF

echo
echo "==> Done. Vendored to $DEST_DIR/{Engine,ThirdParty}"
echo "    Provenance written to $PROVENANCE — commit it alongside the vendored sources."
echo "    Next: re-run after adding the Flutter plugin bridge in ios/Classes/PaddleOcrNativePlugin.swift"
