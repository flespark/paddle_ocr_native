/// PaddleOCR PP-OCRv6 on-device OCR for Android and iOS.
///
/// Usage:
/// ```dart
/// final ocr = PaddleOcr();
/// await ocr.init(
///   config: PaddleOcrConfig.handwrittenRows(),
///   engine: EngineConfig(numThreads: 4),
/// );
/// final result = await ocr.recognize(imagePath);
/// print('${result.results.length} regions in ${result.totalTimeMs}ms');
/// await ocr.dispose();
/// ```
library;

import 'package:flutter/foundation.dart';

import 'src/paddle_ocr_config.dart';
import 'src/paddle_ocr_platform.dart';
import 'src/paddle_ocr_result.dart';

export 'src/paddle_ocr_config.dart' show PaddleOcrConfig, EngineConfig;
export 'src/paddle_ocr_exception.dart'
    show PaddleOcrErrorCode, PaddleOcrException;
export 'src/paddle_ocr_result.dart' show OcrResult, OcrPoint, OcrRunResult;

class PaddleOcr {
  factory PaddleOcr() => _instance;

  PaddleOcr._() : _platform = PaddleOcrNativePlatform.instance;

  @visibleForTesting
  PaddleOcr.withPlatform(this._platform);

  static final PaddleOcr _instance = PaddleOcr._();

  final PaddleOcrNativePlatform _platform;
  bool _initialized = false;
  Future<void> _operations = Future<void>.value();

  /// Loads the PP-OCRv6 det + rec models and creates the ONNX Runtime
  /// sessions.
  ///
  /// [config] controls cross-platform detection and recognition parameters.
  /// [engine] configures ONNX Runtime threads.
  Future<void> init({
    PaddleOcrConfig config = const PaddleOcrConfig(),
    EngineConfig engine = const EngineConfig(),
  }) {
    return _serialize(() async {
      if (_initialized) return;
      await _platform.init(config: config, engine: engine);
      _initialized = true;
    });
  }

  /// Runs OCR on a local PNG, JPEG, or WebP file at [imagePath].
  Future<OcrRunResult> recognize(String imagePath) {
    return _serialize(() {
      if (!_initialized) {
        throw StateError('PaddleOcr not initialized. Call init() first.');
      }
      if (imagePath.trim().isEmpty) {
        throw ArgumentError.value(imagePath, 'imagePath', 'Must not be empty');
      }
      return _platform.recognize(imagePath);
    });
  }

  /// Releases native ONNX sessions. Safe to call multiple times.
  Future<void> dispose() {
    return _serialize(() async {
      if (_initialized) {
        await _platform.release();
        _initialized = false;
      }
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }
}
