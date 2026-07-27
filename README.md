# paddle_ocr_native

Offline PaddleOCR PP-OCRv6 text detection and recognition for Flutter on
Android and iOS. The plugin runs entirely on device with ONNX Runtime and
OpenCV and bundles the PP-OCRv6 small Chinese/English models.

[Chinese documentation](doc/README_zh.md)

> This is an independent community package. It is not an official
> PaddlePaddle Flutter distribution.

## Features

- On-device OCR with no image upload or runtime network dependency.
- PP-OCRv6 small detection and recognition models included in the package.
- Four-point text polygons, recognition confidence, and native timing data.
- Shared Dart API and configuration behavior on Android and iOS.
- Tunable DB detection thresholds and an experimental handwritten-row preset.
- Deterministic model provenance and SHA-256 verification.

## Compatibility

| Platform | Minimum | Architecture | Backend | Status |
| --- | --- | --- | --- | --- |
| Android | API 26 | arm64-v8a | ONNX Runtime 1.21.1, OpenCV 4.13 | Supported |
| iOS | iOS 16 | arm64 device | ONNX Runtime 1.24, OpenCV 4.3 | Supported |
| iOS simulator | - | arm64 simulator | - | Not supported |
| Web/desktop | - | - | - | Not supported |

The iOS OpenCV 4.3 dependency does not contain an Apple Silicon simulator
slice. Use a physical iOS device for builds and tests. Android currently ships
only `arm64-v8a` to keep the supported runtime surface explicit.

The plugin currently supports CocoaPods, not Flutter Swift Package Manager.
Flutter 3.44 prints a compatibility warning and falls back to CocoaPods; keep
CocoaPods enabled in the host project. Swift Package Manager support is a
future compatibility item for the ONNX Runtime/OpenCV binary dependency chain.

Required toolchains are Flutter 3.44+, Dart 3.12+, Java 17, Android SDK 36,
and Xcode 16+ with CocoaPods for iOS.

The iOS host must target iOS 16 and use static CocoaPods framework linkage
because OpenCV 4.3 contains a statically linked framework:

```ruby
# ios/Podfile
platform :ios, '16.0'

target 'Runner' do
  use_frameworks! :linkage => :static
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

Set every Pods target's `IPHONEOS_DEPLOYMENT_TARGET` to `16.0` in the Podfile
`post_install` hook as demonstrated by the included example.

## Installation

```shell
flutter pub add paddle_ocr_native
```

Or add the version explicitly:

```yaml
dependencies:
  paddle_ocr_native: ^0.1.0
```

No camera, photo-library, or network permission is required by the plugin.
The host application must declare permissions for whichever image source it
chooses to use.

Restrict Android packaging to the supported ABI. With current Android Gradle
Plugin versions, `abiFilters` alone can retain prebuilt JNI libraries from the
transitive ONNX Runtime and OpenCV AARs, so also exclude unsupported ABI
directories:

```kotlin
// android/app/build.gradle.kts
android {
    defaultConfig {
        ndk { abiFilters += "arm64-v8a" }
    }
    packaging {
        jniLibs {
            excludes += setOf(
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
            )
        }
    }
}
```

## Usage

```dart
import 'package:paddle_ocr_native/paddle_ocr_native.dart';

final ocr = PaddleOcr();

await ocr.init(
  config: const PaddleOcrConfig(),
  engine: const EngineConfig(numThreads: 4),
);

final run = await ocr.recognize('/absolute/path/to/image.jpg');
for (final region in run.results) {
  print('${region.text} ${region.confidence.toStringAsFixed(3)}');
  print(region.points);       // Polygon in source-image pixels.
  print(region.boundingBox);  // Axis-aligned enclosing Rect.
}

print('Detection: ${run.detectionTimeMs} ms');
print('Recognition: ${run.recognitionTimeMs} ms');

await ocr.dispose();
```

`PaddleOcr()` is a process-wide shared engine owner. Initialization and
recognition calls are serialized. `init` and `dispose` are idempotent, and the
engine can be initialized again after disposal.

The input must be an absolute path to a local PNG, JPEG, or WebP image. An
empty path throws `ArgumentError`; recognition before initialization throws
`StateError`; native failures are reported as `PaddleOcrException` with a
stable `PaddleOcrErrorCode`.

## Configuration

`PaddleOcrConfig` exposes only values that are implemented consistently on
both platforms:

| Field | Default | Purpose |
| --- | ---: | --- |
| `detThresh` | `0.3` | DB probability-map threshold |
| `detBoxThresh` | `0.6` | Minimum average box score |
| `detUnclipRatio` | `1.5` | Polygon expansion ratio |
| `detLimitSideLen` | `960` | Detection resize target |
| `detLimitType` | `max` | Resize mode, `min` or `max` |
| `detMaxSideLimit` | `4000` | Hard resized-side cap |
| `recScoreThresh` | `0.0` | Minimum recognition confidence |
| `recBatchSize` | `6` | Recognition batch size |

For tightly spaced handwriting, try the experimental preset:

```dart
await ocr.init(config: const PaddleOcrConfig.handwrittenRows());
```

Changing preprocessing or postprocessing values can materially change OCR
output. Validate tuned configurations on representative images from every
supported platform.

## Models and application size

The package includes approximately 29 MB of ONNX weights plus recognition
configuration and character data. This provides offline, installation-time
availability at the cost of a larger application. Custom model paths and
runtime model downloads are not part of the 0.1 API.

See [model provenance](doc/model-provenance.md) for source URLs, licenses,
sizes, and SHA-256 values.

## Example and testing

The [example](example/) can recognize its bundled sample or an image selected
from the photo library:

```shell
cd example
flutter run -d <android-or-ios-device>
```

Run package checks from the repository root:

```shell
flutter analyze
flutter test
flutter pub publish --dry-run
```

Run the native smoke test on a supported physical device:

```shell
cd example
flutter test integration_test/ocr_smoke_test.dart -d <device-id>

# Equivalent Flutter Driver form
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/ocr_smoke_test.dart -d <device-id>
```

## Troubleshooting

- `INIT_FAILED`: verify that all four files under `assets/models/` are in the
  package and that CocoaPods/Gradle dependencies resolved successfully.
- `DECODE_FAILED`: pass an absolute path to a readable PNG, JPEG, or WebP file.
- Android install failure: use an arm64-v8a physical device or arm64 emulator
  running API 26 or newer.
- iOS simulator build failure: this is expected with the current OpenCV 4.3
  binary. Build for an arm64 physical device.
- Flutter reports missing Swift Package Manager support: this is expected for
  0.1.0; the plugin uses the host CocoaPods integration described above.
- CocoaPods reports a transitive static binary: change the host Podfile from
  `use_frameworks!` to `use_frameworks! :linkage => :static`.
- Slow first call: `init` creates two ONNX Runtime sessions. Reuse the shared
  `PaddleOcr` instance instead of disposing it after every image.

## Architecture and upstream code

The Dart API calls a MethodChannel implemented in Kotlin and Swift. Each native
implementation decodes the image, runs PP-OCRv6 detection, crops detected
regions, runs recognition, and returns text polygons and timing data.

Android and iOS engine sources are vendored from pinned PaddleOCR commits and
retain their upstream license headers. Local bridge and asset-loading changes
are documented in [upstream maintenance](doc/upstream.md). A more detailed
flow is available in [architecture](doc/architecture.md).

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Clipper1's
Boost Software License is preserved in its vendored source directory.
