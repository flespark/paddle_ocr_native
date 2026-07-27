# Architecture

```text
Dart PaddleOcr
  -> serialized lifecycle and MethodChannel
     -> Android Kotlin or iOS Swift bridge
        -> decode local image
        -> PP-OCRv6 DB detection (ONNX Runtime)
        -> OpenCV polygon postprocessing and region crop
        -> PP-OCRv6 text recognition (ONNX Runtime)
        -> text, confidence, four points, and timing
```

The two platforms share one wire contract:

- `init(config, engine)` loads bundled model assets and returns cold-load data.
- `recognize(imagePath)` returns regions and detection/recognition milliseconds.
- `release()` releases or drops native ONNX Runtime sessions.

The public configuration includes only parameters consumed by both backends.
Android maps them into `PaddleOCRConfig`; iOS maps them into
`OCRRuntimeParams` before the first run. Model normalization, tensor shapes,
candidate selection, and execution provider selection remain internal because
their current implementations are not cross-platform equivalent.

The plugin exposes one process-wide `PaddleOcr` owner. Dart serializes native
operations so recognition cannot race release. Platform channel errors are
translated to stable `PaddleOcrException` categories.
