# paddle_ocr_native example

Demonstrates offline PP-OCRv6 detection and recognition with
`paddle_ocr_native`. The app can process the included Apache-2.0 benchmark
image or an image selected from the device photo library, then displays text,
confidence, source-image polygon coordinates, and native inference timings.

## Run

Use an Android arm64 device or emulator running API 26 or newer, or an iOS 16+
arm64 physical device:

```shell
flutter pub get
flutter run -d <device-id>
```

The current OpenCV iOS dependency has no Apple Silicon simulator slice, so an
iOS simulator is not a supported target.

## Test

The widget test does not load the native OCR engine:

```shell
flutter test
```

Run the end-to-end OCR smoke test on a supported physical device:

```shell
flutter test integration_test/ocr_smoke_test.dart -d <device-id>

# Equivalent Flutter Driver form
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/ocr_smoke_test.dart -d <device-id>
```

See the package [README](../README.md) for host configuration, API usage, and
troubleshooting.
