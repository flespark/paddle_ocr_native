# Upstream source maintenance

## Android

- Repository: `https://github.com/PaddlePaddle/PaddleOCR`
- Path: `deploy/ppocr-android/ppocr-sdk/`
- Commit: `1af0448a200eae430b9addb40e7118d67f9840ab`
- License: Apache-2.0

The Kotlin source under `android/ppocr-sdk/` is vendored. The Flutter package
compiles it directly and supplies its own Gradle dependencies. OpenCV is changed
from the unmaintained QuickBird 4.5.3 artifact to the official OpenCV 4.13 Maven
artifact because the old binary fails to load on Android 14 and newer. The
algorithm source is otherwise kept attributable to upstream.

## iOS

- Repository: `https://github.com/PaddlePaddle/PaddleOCR`
- Path: `deploy/ios_demo/PaddleOCRDemo/`
- Commit: `2661c7c0ef5c613e8f93c6e93b2e052399f0f854`
- License: Apache-2.0, plus Boost Software License 1.0 for Clipper1

Only the engine and Clipper1 source are vendored. The sample SwiftUI shell,
view models, resources, and upstream tests are excluded. Local files add the
Flutter MethodChannel, resolve models copied from Flutter assets, import the
ONNX Runtime CocoaPod module explicitly, and retain one Swift compatibility
fix. Local modifications carry prominent notices.

## Upgrade procedure

1. Choose and review a specific upstream commit.
2. Update the pinned ref in the vendor script; never publish from a moving
   branch reference.
3. Re-vendor and inspect the complete source diff, including license headers.
4. Reapply the documented local patches and remove patches accepted upstream.
5. Rebuild the example for Android arm64 and iOS arm64 device targets.
6. Run the same-image native integration and configuration A/B tests.
7. Update `ios/Classes/UPSTREAM.md`, model provenance when relevant, and the
   changelog before release.
