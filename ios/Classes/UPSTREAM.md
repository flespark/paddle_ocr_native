# Vendored from PaddleOCR deploy/ios_demo

Upstream repository: https://github.com/PaddlePaddle/PaddleOCR
Path prefix:         deploy/ios_demo/PaddleOCRDemo/
Pinned ref:          2661c7c0ef5c613e8f93c6e93b2e052399f0f854
Resolved SHA:        2661c7c0ef5c613e8f93c6e93b2e052399f0f854
Date vendored:       2026-07-22T12:26:59Z

## Scope

Only `Engine/` (Swift + ObjC++ bridge sources) and `ThirdParty/Clipper1/`
(C++ polygon offset, Boost Software License 1.0) are vendored. SwiftUI views /
view-models / sample resources / unit tests of the official demo are NOT vendored
because they are app-shell concerns that belong to the PaddleOcrDemo sample,
not the OCR engine itself.

## Local additions (not part of upstream)

- `PaddleOcrNativePlugin.swift` — Flutter MethodChannel bridge to `OCREngine`,
  mirroring the wire format of `android/src/main/kotlin/.../PaddleOcrNativePlugin.kt`.

## Upgrade procedure

1. Edit `PADDLE_OCR_REF` in `scripts/vendor_ios_demo_engine.sh` to the new
   ref (commit SHA recommended).
2. Rerun the script.
3. `git diff ios/Classes/Engine` to inspect upstream changes; resolve any
   bridging incompatibilities in `PaddleOcrNativePlugin.swift`.
4. Update this file with the new SHA + date.
