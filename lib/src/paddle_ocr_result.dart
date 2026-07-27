import 'dart:ui' show Rect;

/// A 2D point on the recognized image, in image pixel coordinates.
///
/// Both native backends return integer source-image coordinates.
class OcrPoint {
  final int x;
  final int y;

  const OcrPoint({required this.x, required this.y});

  @override
  String toString() => '($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrPoint && other.x == x && other.y == y);

  @override
  int get hashCode => Object.hash(x, y);
}

/// One detected text region returned by PaddleOCR.
class OcrResult {
  final String text;
  final double confidence;
  final List<OcrPoint> points;
  final int clsLabel;
  final double clsScore;

  const OcrResult({
    required this.text,
    required this.confidence,
    required this.points,
    this.clsLabel = -1,
    this.clsScore = 0.0,
  });

  /// Axis-aligned bounding box enclosing all polygon points.
  Rect get boundingBox {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.x.toDouble();
    var minY = points.first.y.toDouble();
    var maxX = minX;
    var maxY = minY;
    for (final p in points.skip(1)) {
      final x = p.x.toDouble();
      final y = p.y.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (maxX <= minX || maxY <= minY) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  factory OcrResult.fromMap(Map<String, dynamic> map) {
    final pointsList =
        (map['points'] as List?)?.map((p) {
          final pm = Map<String, dynamic>.from(p as Map);
          return OcrPoint(x: pm['x'] as int, y: pm['y'] as int);
        }).toList() ??
        [];

    return OcrResult(
      text: map['text'] as String? ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      points: pointsList,
      clsLabel: map['clsLabel'] as int? ?? -1,
      clsScore: (map['clsScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() =>
      'OcrResult(text: "$text", confidence: ${confidence.toStringAsFixed(3)}, '
      'points: ${points.length})';
}

/// Detection and recognition results with native-side timing.
class OcrRunResult {
  final List<OcrResult> results;
  final int detectionTimeMs;
  final int recognitionTimeMs;

  const OcrRunResult({
    required this.results,
    required this.detectionTimeMs,
    required this.recognitionTimeMs,
  });

  /// Empty / failed run sentinel.
  static const empty = OcrRunResult(
    results: [],
    detectionTimeMs: 0,
    recognitionTimeMs: 0,
  );

  int get totalTimeMs => detectionTimeMs + recognitionTimeMs;

  @override
  String toString() =>
      'OcrRunResult(${results.length} regions, det=${detectionTimeMs}ms, '
      'rec=${recognitionTimeMs}ms)';
}
