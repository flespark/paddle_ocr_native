# Model provenance

The release bundles PP-OCRv6 small ONNX files published by PaddlePaddle on
Hugging Face. Both model repositories declare Apache-2.0.

| File | Upstream repository | SHA-256 |
| --- | --- | --- |
| `assets/models/det/inference.onnx` | `PaddlePaddle/PP-OCRv6_small_det_onnx` | `d73e0058b7a8086bbd57f3d10b8bcd4ff95363f67e06e2762b5e814fe9c9410e` |
| `assets/models/det/inference.yml` | `PaddlePaddle/PP-OCRv6_small_det_onnx` | `193f435274bf9f0b5f71a929bbfbcf148282df7e633b34e7c373e8f44741b516` |
| `assets/models/rec/inference.onnx` | `PaddlePaddle/PP-OCRv6_small_rec_onnx` | `5435fd747c9e0efe15a96d0b378d5bd157e9492ed8fd80edf08f30d02fa24634` |
| `assets/models/rec/inference.yml` | `PaddlePaddle/PP-OCRv6_small_rec_onnx` | `ab078671bb49f06228eadccd34f1bb501e157f7a047095ffb943ba81512c77d1` |

Source URLs are defined in `scripts/download_ppocrv6_small.sh`. The URLs use
the upstream `main` download endpoint because Hugging Face does not expose a
stable release tag for these artifacts; reviewed SHA-256 values pin the actual
content and make an upstream replacement fail closed.

To update the models:

1. Review the upstream model card and license.
2. Download to a temporary location and evaluate both supported platforms.
3. Update the four expected hashes in the script.
4. Run the script and the Android/iOS integration suites.
5. Record size, latency, accuracy deltas, source revision, and date here.

The example sample image is copied from PaddleOCR's Android SDK benchmark
fixture at the Android source commit documented in `doc/upstream.md` and is
distributed under the same Apache-2.0 license.
