# Contributing

Issues and pull requests are welcome. For behavior changes, open an issue first
so platform compatibility and model implications can be discussed.

## Development setup

1. Install Flutter 3.44 or newer, Android SDK 36, Java 17, and Xcode 16 or
   newer when working on iOS.
2. Run `flutter pub get` at the repository root and in `example/`.
3. Run `flutter analyze` and `flutter test` before submitting a change.
4. Build `example/` for Android arm64 and iOS arm64 when changing native code.

Changes to OCR parameters, preprocessing, postprocessing, or model files must
include an integration-test comparison on both supported platforms. Model
updates must also update `doc/model-provenance.md` and the checksums in
`scripts/download_ppocrv6_small.sh`.

By contributing, you agree that your contribution is licensed under the
Apache License 2.0.
