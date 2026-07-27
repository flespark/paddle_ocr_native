/// Cross-platform PaddleOCR detection and recognition configuration.
///
/// Every field is applied on both Android and iOS during [PaddleOcr.init].
/// Defaults match the PaddleOCR Android SDK defaults.
class PaddleOcrConfig {
  // ---- Detection (DB) ----
  /// Pixel probability threshold for binarizing the DB segmentation map.
  /// Boxes are formed from connected components above this threshold.
  final double detThresh;

  /// Threshold applied to the averaged segmentation score inside a candidate
  /// box — boxes below this average are dropped.
  final double detBoxThresh;

  /// Unclip ratio for expanding each raw DB box back to the text stroke size.
  /// Larger values produce looser boxes and can merge adjacent text rows.
  final double detUnclipRatio;

  /// Target side length for resizing the input before detection. Larger →
  /// finer small text at the cost of latency.
  final int detLimitSideLen;

  /// `"min"` resizes the longest side down to [detLimitSideLen] only when the
  /// image exceeds it; `"max"` always resizes to exactly [detLimitSideLen].
  final String detLimitType;

  /// Hard cap on the longest side after resize, regardless of [detLimitType].
  final int detMaxSideLimit;

  // ---- Recognition ----
  /// Confidence threshold for accepting a recognized string; below it the
  /// box is dropped from results.
  final double recScoreThresh;

  /// Batch size for the recognition forward pass. Larger increases throughput
  /// on many-box images at the cost of memory.
  final int recBatchSize;

  const PaddleOcrConfig({
    this.detThresh = 0.3,
    this.detBoxThresh = 0.6,
    this.detUnclipRatio = 1.5,
    this.detLimitSideLen = 960,
    this.detLimitType = 'max',
    this.detMaxSideLimit = 4000,
    this.recScoreThresh = 0.0,
    this.recBatchSize = 6,
  }) : assert(detThresh >= 0 && detThresh <= 1),
       assert(detBoxThresh >= 0 && detBoxThresh <= 1),
       assert(detUnclipRatio > 0),
       assert(detLimitSideLen > 0),
       assert(detLimitType == 'min' || detLimitType == 'max'),
       assert(detMaxSideLimit > 0),
       assert(recScoreThresh >= 0 && recScoreThresh <= 1),
       assert(recBatchSize > 0);

  /// Experimental preset for tightly spaced handwritten rows.
  ///
  /// Values were selected through cross-platform A/B testing on a tightly
  /// spaced, 16-row handwritten order image:
  /// - `detUnclipRatio 1.0` (vs default 1.5 / first-try 1.2) — tightest boxes,
  ///   adjacent rows stay cleanly separated for clustering.
  /// - `detBoxThresh 0.5` (vs default 0.6) — keeps weak/narrow rows that the
  ///   sample needs (handwriting strokes are thinner than print).
  /// - `detLimitSideLen 1536` (vs default 960 / first-try 1280) — higher
  ///   resolution so small handwriting is detectable.
  /// - `recScoreThresh 0.0` keeps every recognized string so callers can apply
  ///   application-specific filtering or row clustering.
  const PaddleOcrConfig.handwrittenRows()
    : detThresh = 0.3,
      detBoxThresh = 0.5,
      detUnclipRatio = 1.0,
      detLimitSideLen = 1536,
      detLimitType = 'max',
      detMaxSideLimit = 4000,
      recScoreThresh = 0.0,
      recBatchSize = 6;

  /// Serializes to the Map shape expected by the Kotlin MethodChannel.
  Map<String, dynamic> toMap() => {
    'detThresh': detThresh,
    'detBoxThresh': detBoxThresh,
    'detUnclipRatio': detUnclipRatio,
    'detLimitSideLen': detLimitSideLen,
    'detLimitType': detLimitType,
    'detMaxSideLimit': detMaxSideLimit,
    'recScoreThresh': recScoreThresh,
    'recBatchSize': recBatchSize,
  };

  @override
  String toString() =>
      'PaddleOcrConfig(detUnclipRatio=$detUnclipRatio, '
      'detBoxThresh=$detBoxThresh, detLimitSideLen=$detLimitSideLen, '
      'recScoreThresh=$recScoreThresh)';
}

/// ONNX Runtime CPU execution configuration.
class EngineConfig {
  /// Intra-op threads for ONNX Runtime. 4 is a good default for the
  /// big-core cluster on mid-range Android devices.
  final int numThreads;

  const EngineConfig({this.numThreads = 4}) : assert(numThreads > 0);

  Map<String, dynamic> toMap() => {'numThreads': numThreads};
}
