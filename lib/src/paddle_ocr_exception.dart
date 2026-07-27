/// Stable error categories emitted by the native OCR backends.
enum PaddleOcrErrorCode {
  initializationFailed,
  invalidArguments,
  imageDecodeFailed,
  modelLoadFailed,
  recognitionFailed,
  unknown,
}

/// An OCR failure reported by Android or iOS.
class PaddleOcrException implements Exception {
  const PaddleOcrException({
    required this.code,
    required this.message,
    this.details,
  });

  final PaddleOcrErrorCode code;
  final String message;
  final Object? details;

  @override
  String toString() => 'PaddleOcrException(${code.name}): $message';
}
