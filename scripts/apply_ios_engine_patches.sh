#!/usr/bin/env bash
#
# Patches the vendored PaddleOCR iOS demo `Engine/` after the vendor step
# in `scripts/vendor_ios_demo_engine.sh`. Each patch fixes an upstream
# issue that prevents the code from compiling when used as a Flutter plugin
# (rather than inside the official PaddleOCRDemo app shell).
#
# Re-applied automatically on every `vendor_ios_demo_engine.sh` run; idempotent.
#
# Patches:
#
#  1. ORTSessionManager.swift — add `import onnxruntime_objc`.
#     The official demo relies on the demo app target's automatic
#     framework bridging for ORTEnv/ORTSession etc. As a standalone pod
#     target, the .swift file needs an explicit `import` so its references
#     to ORT types resolve against the CocoaPod's module
#     (`onnxruntime_objc` — hyphen→underscore per Swift module-name rules).
#
#  2. OCRParameterResolver.swift — remove trailing comma in
#     `ResolvedOCRRuntimeParams.init(...)` parameter list (line ~67).
#     Apple's modern Swift parser rejects this on `init` argument lists
#     even though the upstream demo's older Xcode Swift driver accepted it.
#
# For upgrades: edit this script if the upstream file layout changes
# (e.g. line numbers shift, identifiers renamed). Re-run, commit the new
# edited files under `ios/Classes/Engine/`, and update the PADDLE_OCR_NATIVE LOCAL PATCH
# note in those Swift files' leading comments.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_DIR="$PLUGIN_DIR/ios/Classes/Engine"

if [ ! -d "$ENGINE_DIR" ]; then
  echo "[apply_ios_engine_patches.sh] missing $ENGINE_DIR — run vendor_ios_demo_engine.sh first" >&2
  exit 1
fi

# --- Patch 1: add `import onnxruntime_objc` to ORTSessionManager.swift ---
ORT="$ENGINE_DIR/ORTSessionManager.swift"
if [ -f "$ORT" ]; then
  if ! grep -q "^import onnxruntime_objc" "$ORT"; then
    # Insert immediately after `import Foundation` (the first import).
    # portable sed: head -1 with N to pair lines, then conditionally insert.
    perl -0pi -e 's/import Foundation\n/import Foundation\nimport onnxruntime_objc  \/\/ PADDLE_OCR_NATIVE LOCAL PATCH: provides ORTEnv \/ ORTSession \/ ORTSessionOptions \/ ORTValue \/ ORTXnnpackExecutionProviderOptions \/ ORTCoreMLExecutionProviderOptions\n/' "$ORT"
    echo "[apply_ios_engine_patches.sh] ORTSessionManager.swift: added import onnxruntime_objc"
  else
    echo "[apply_ios_engine_patches.sh] ORTSessionManager.swift: import onnxruntime_objc already present, skipping"
  fi
fi

# --- Patch 2: remove trailing comma in ResolvedOCRRuntimeParams.init(:) ---
RES="$ENGINE_DIR/OCRParameterResolver.swift"
if [ -f "$RES" ]; then
  # Match `textRecScoreThresh: Float,\n    )` and collapse to no trailing comma.
  if perl -0pi -e 's/(textRecScoreThresh:\s*Float),(\s*\n\s*)\)/$1$2)/' "$RES"; then
    if grep -q "textRecScoreThresh: Float" "$RES" && ! grep -E "textRecScoreThresh:\s*Float,\s*\$" "$RES" >/dev/null; then
      echo "[apply_ios_engine_patches.sh] OCRParameterResolver.swift: trailing comma removed"
    else
      echo "[apply_ios_engine_patches.sh] OCRParameterResolver.swift: idempotent (already no trailing comma)"
    fi
  fi
fi

echo "[apply_ios_engine_patches.sh] done."