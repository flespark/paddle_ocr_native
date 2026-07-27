# Security policy

## Supported versions

Security fixes are provided for the latest published minor release.

## Reporting a vulnerability

Do not open a public issue for a vulnerability. Use GitHub's private security
advisory form for `flespark/paddle_ocr_native` and include affected versions,
platforms, reproduction steps, and impact. Avoid attaching images that contain
personal or confidential text.

The plugin performs OCR entirely on device and does not upload images. Its
model-update script is a maintainer tool and verifies every downloaded file
against a reviewed SHA-256 digest.
