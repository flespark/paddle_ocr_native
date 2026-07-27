#!/usr/bin/env bash
#
# Downloads PP-OCRv6_small ONNX models from HuggingFace into this plugin's
# assets/ directory for maintainers updating the bundled model release.
#
#   bash scripts/download_ppocrv6_small.sh
#
# The files are committed and published with the package. Every download is
# checked against the reviewed release hashes below.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DET_DIR="$PLUGIN_DIR/assets/models/det"
REC_DIR="$PLUGIN_DIR/assets/models/rec"
mkdir -p "$DET_DIR" "$REC_DIR"

DET_URL="https://huggingface.co/PaddlePaddle/PP-OCRv6_small_det_onnx/resolve/main/inference.onnx"
DET_YML_URL="https://huggingface.co/PaddlePaddle/PP-OCRv6_small_det_onnx/resolve/main/inference.yml"
REC_ONNX_URL="https://huggingface.co/PaddlePaddle/PP-OCRv6_small_rec_onnx/resolve/main/inference.onnx"
REC_YML_URL="https://huggingface.co/PaddlePaddle/PP-OCRv6_small_rec_onnx/resolve/main/inference.yml"

DET_SHA256="d73e0058b7a8086bbd57f3d10b8bcd4ff95363f67e06e2762b5e814fe9c9410e"
DET_YML_SHA256="193f435274bf9f0b5f71a929bbfbcf148282df7e633b34e7c373e8f44741b516"
REC_SHA256="5435fd747c9e0efe15a96d0b378d5bd157e9492ed8fd80edf08f30d02fa24634"
REC_YML_SHA256="ab078671bb49f06228eadccd34f1bb501e157f7a047095ffb943ba81512c77d1"

# Prefer curl (macOS default), fall back to wget.
download() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$dest" "$url"
    else
        wget -q --tries=3 -O "$dest" "$url"
    fi
}

verify() {
    local expected="$1" file="$2" actual
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "Checksum mismatch for $file" >&2
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 1
    fi
}

echo "→ detection model"
download "$DET_URL" "$DET_DIR/inference.onnx"
echo "→ detection config (yml)"
download "$DET_YML_URL" "$DET_DIR/inference.yml"
echo "→ recognition model (onnx)"
download "$REC_ONNX_URL" "$REC_DIR/inference.onnx"
echo "→ recognition config (yml)"
download "$REC_YML_URL" "$REC_DIR/inference.yml"

verify "$DET_SHA256" "$DET_DIR/inference.onnx"
verify "$DET_YML_SHA256" "$DET_DIR/inference.yml"
verify "$REC_SHA256" "$REC_DIR/inference.onnx"
verify "$REC_YML_SHA256" "$REC_DIR/inference.yml"

echo
echo "Done. Sizes:"
du -h "$DET_DIR/inference.onnx" "$DET_DIR/inference.yml" "$REC_DIR/inference.onnx" "$REC_DIR/inference.yml"
