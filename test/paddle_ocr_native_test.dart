import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paddle_ocr_native/paddle_ocr_native.dart';
import 'package:paddle_ocr_native/src/paddle_ocr_method_channel.dart';
import 'package:paddle_ocr_native/src/paddle_ocr_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaddleOcrConfig', () {
    test('defaults serialize every cross-platform field', () {
      const config = PaddleOcrConfig();

      expect(config.toMap(), {
        'detThresh': 0.3,
        'detBoxThresh': 0.6,
        'detUnclipRatio': 1.5,
        'detLimitSideLen': 960,
        'detLimitType': 'max',
        'detMaxSideLimit': 4000,
        'recScoreThresh': 0.0,
        'recBatchSize': 6,
      });
    });

    test('handwrittenRows keeps tightly spaced rows separate', () {
      const config = PaddleOcrConfig.handwrittenRows();

      expect(config.detUnclipRatio, 1.0);
      expect(config.detBoxThresh, 0.5);
      expect(config.detLimitSideLen, 1536);
      expect(config.recScoreThresh, 0.0);
    });

    test('rejects invalid configuration', () {
      expect(() => PaddleOcrConfig(detThresh: 1.1), throwsAssertionError);
      expect(() => PaddleOcrConfig(detLimitType: 'long'), throwsAssertionError);
      expect(() => EngineConfig(numThreads: 0), throwsAssertionError);
    });
  });

  group('OcrResult', () {
    test('parses the native wire shape and calculates its bounding box', () {
      final result = OcrResult.fromMap({
        'text': 'PaddleOCR',
        'confidence': 0.92,
        'points': [
          {'x': 10, 'y': 100},
          {'x': 200, 'y': 100},
          {'x': 200, 'y': 130},
          {'x': 10, 'y': 130},
        ],
        'clsLabel': -1,
        'clsScore': 0.0,
      });

      expect(result.text, 'PaddleOCR');
      expect(result.confidence, closeTo(0.92, 1e-6));
      expect(result.points, const [
        OcrPoint(x: 10, y: 100),
        OcrPoint(x: 200, y: 100),
        OcrPoint(x: 200, y: 130),
        OcrPoint(x: 10, y: 130),
      ]);
      expect(result.boundingBox.left, 10);
      expect(result.boundingBox.top, 100);
      expect(result.boundingBox.right, 200);
      expect(result.boundingBox.bottom, 130);
    });

    test('missing optional wire fields produce an empty result', () {
      final result = OcrResult.fromMap(<String, dynamic>{});

      expect(result.text, isEmpty);
      expect(result.confidence, 0);
      expect(result.points, isEmpty);
      expect(result.boundingBox.isEmpty, isTrue);
    });
  });

  group('PaddleOcr lifecycle', () {
    test('the public constructor returns one shared native engine owner', () {
      expect(identical(PaddleOcr(), PaddleOcr()), isTrue);
    });

    test('recognize requires initialization and a non-empty path', () async {
      final platform = _FakePlatform();
      final ocr = PaddleOcr.withPlatform(platform);

      await expectLater(ocr.recognize('/tmp/image.jpg'), throwsStateError);
      await ocr.init();
      await expectLater(ocr.recognize('  '), throwsArgumentError);
    });

    test('init and dispose are idempotent', () async {
      final platform = _FakePlatform();
      final ocr = PaddleOcr.withPlatform(platform);

      await ocr.init();
      await ocr.init();
      await ocr.dispose();
      await ocr.dispose();

      expect(platform.initCalls, 1);
      expect(platform.releaseCalls, 1);
    });

    test('recognition calls execute serially', () async {
      final platform = _FakePlatform(delay: const Duration(milliseconds: 5));
      final ocr = PaddleOcr.withPlatform(platform);
      await ocr.init();

      await Future.wait([
        ocr.recognize('/tmp/first.png'),
        ocr.recognize('/tmp/second.png'),
      ]);

      expect(platform.maxConcurrentRecognitions, 1);
    });
  });

  group('MethodChannelPaddleOcrNative', () {
    const channel = MethodChannel('paddle_ocr_native');

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('maps native error codes to stable Dart exceptions', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'DECODE_FAILED',
              message: 'Cannot decode image',
            );
          });
      final platform = MethodChannelPaddleOcrNative();

      await expectLater(
        platform.recognize('/missing.png'),
        throwsA(
          isA<PaddleOcrException>()
              .having(
                (error) => error.code,
                'code',
                PaddleOcrErrorCode.imageDecodeFailed,
              )
              .having(
                (error) => error.message,
                'message',
                'Cannot decode image',
              ),
        ),
      );
    });
  });
}

class _FakePlatform extends PaddleOcrNativePlatform {
  _FakePlatform({this.delay = Duration.zero});

  final Duration delay;
  int initCalls = 0;
  int releaseCalls = 0;
  int _activeRecognitions = 0;
  int maxConcurrentRecognitions = 0;

  @override
  Future<Map<String, dynamic>> init({
    required PaddleOcrConfig config,
    required EngineConfig engine,
  }) async {
    initCalls++;
    return {'success': true};
  }

  @override
  Future<OcrRunResult> recognize(String imagePath) async {
    _activeRecognitions++;
    if (_activeRecognitions > maxConcurrentRecognitions) {
      maxConcurrentRecognitions = _activeRecognitions;
    }
    await Future<void>.delayed(delay);
    _activeRecognitions--;
    return OcrRunResult.empty;
  }

  @override
  Future<void> release() async {
    releaseCalls++;
  }
}
