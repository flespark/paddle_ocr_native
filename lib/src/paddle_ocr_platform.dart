import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'paddle_ocr_config.dart';
import 'paddle_ocr_method_channel.dart';
import 'paddle_ocr_result.dart';

abstract class PaddleOcrNativePlatform extends PlatformInterface {
  PaddleOcrNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static PaddleOcrNativePlatform _instance = MethodChannelPaddleOcrNative();

  static PaddleOcrNativePlatform get instance => _instance;

  static set instance(PaddleOcrNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Map<String, dynamic>> init({
    required PaddleOcrConfig config,
    required EngineConfig engine,
  }) {
    throw UnimplementedError('init() has not been implemented.');
  }

  Future<OcrRunResult> recognize(String imagePath) {
    throw UnimplementedError('recognize() has not been implemented.');
  }

  Future<void> release() {
    throw UnimplementedError('release() has not been implemented.');
  }
}
