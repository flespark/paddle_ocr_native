import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'paddle_ocr_config.dart';
import 'paddle_ocr_exception.dart';
import 'paddle_ocr_platform.dart';
import 'paddle_ocr_result.dart';

/// MethodChannel-backed implementation talking to [PaddleOcrNativePlugin.kt].
///
/// Wire format is shared by the Android and iOS implementations.
class MethodChannelPaddleOcrNative extends PaddleOcrNativePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('paddle_ocr_native');

  @override
  Future<Map<String, dynamic>> init({
    required PaddleOcrConfig config,
    required EngineConfig engine,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<Map>('init', {
        'config': config.toMap(),
        'engine': engine.toMap(),
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  @override
  Future<OcrRunResult> recognize(String imagePath) async {
    try {
      final raw = await methodChannel.invokeMethod<Map>('recognize', {
        'imagePath': imagePath,
      });
      if (raw == null) return OcrRunResult.empty;

      final regions =
          (raw['results'] as List?)
              ?.map(
                (r) => OcrResult.fromMap(Map<String, dynamic>.from(r as Map)),
              )
              .toList() ??
          [];

      return OcrRunResult(
        results: regions,
        detectionTimeMs: (raw['detectionTimeMs'] as num?)?.toInt() ?? 0,
        recognitionTimeMs: (raw['recognitionTimeMs'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  @override
  Future<void> release() async {
    try {
      await methodChannel.invokeMethod('release');
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  PaddleOcrException _mapPlatformException(PlatformException error) {
    final code = switch (error.code) {
      'INIT_FAILED' => PaddleOcrErrorCode.initializationFailed,
      'INVALID_ARGS' => PaddleOcrErrorCode.invalidArguments,
      'DECODE_FAILED' => PaddleOcrErrorCode.imageDecodeFailed,
      'MODEL_LOAD_FAILED' => PaddleOcrErrorCode.modelLoadFailed,
      'RECOGNIZE_FAILED' => PaddleOcrErrorCode.recognitionFailed,
      _ => PaddleOcrErrorCode.unknown,
    };
    return PaddleOcrException(
      code: code,
      message: error.message ?? 'Native OCR operation failed (${error.code})',
      details: error.details,
    );
  }
}
