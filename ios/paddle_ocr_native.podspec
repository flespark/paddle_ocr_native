#
#  paddle_ocr_native.podspec
#  Flutter plugin - iOS port of PP-OCRv6 OCR.
#
#  Vendors the official PaddleOCR iOS demo's Engine Swift pre/post-processing
#  (deploy/ios_demo/PaddleOCRDemo/Engine/) plus the Clipper1 polygon offset C++
#  source, and bridges to Flutter via the `paddle_ocr_native` MethodChannel.
#  Wire format mirrors the Android PaddleOcrNativePlugin implementation.
#
#  See README.md for upstream commit pin + provenance (mirrors Android ppocr-sdk).
#

Pod::Spec.new do |s|
  s.name             = 'paddle_ocr_native'
  s.version          = '0.1.0'
  s.summary          = 'Offline PaddleOCR PP-OCRv6 for Flutter on iOS.'
  s.description      = <<-DESC
Offline OCR for Flutter. Vendors the official PaddleOCR PP-OCRv6 iOS demo's
Swift pre/post-processing (DetectionEngine,
RecognitionEngine, OCREngine, ORTSessionManager, Preprocessing, RecPreprocessor,
DBPostProcess, CTCDecoder, BoxSorter, QuadTextCrop, EncodedImageCodec), plus the
Clipper1 polygon offset C++ source and OpenCV Objective-C++ bridges. Bundles
PP-OCRv6_small ONNX models (loaded from Flutter assets at init time).
                       DESC
  s.homepage         = 'https://github.com/flespark/paddle_ocr_native'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'flespark'
  s.source           = { :path => '.' }

  s.platform         = :ios, '16.0'
  s.ios.deployment_target = '16.0'
  s.swift_version    = '5.9'

  # Flutter podspec convention: Flutter framework + plugin sources.
  # `.cpp` is needed so the Clipper1 C++ source (`clipper.cpp` exposed via
  # PDBPolygonOffsetBridge.mm) actually compiles — without it we got linker
  # "Undefined symbol: ClipperLib::ClipperOffset" errors.
  s.source_files = 'Classes/**/*.{swift,h,m,mm,cpp}'

  # Clipper1 is C++ vendored source; preserve outside source_files glob is
  # used here purely as a cue for cross-version compatibility upgrades.
  s.preserve_paths = 'Classes/ThirdParty/Clipper1/**/*'

  # Explicitly exclude the Clipper1 LICENSE from being treated as
  # buildable source (preserved above is enough).
  s.exclude_files = 'Classes/ThirdParty/Clipper1/LICENSE'

  s.public_header_files = 'Classes/**/*.{h}'

  # C++ standard library + Objective-C++ runtime for the .mm bridges.
  s.libraries = 'c++'

  s.dependency 'Flutter'
  s.dependency 'onnxruntime-objc', '~> 1.24'
  s.dependency 'OpenCV', '~> 4.3.0'
  s.dependency 'Yams', '~> 5.0'

  # onnxruntime-objc ships headers that use #include "..." inside framework
  # headers; newer Xcode treats that as an error. Allow Pods to build.
  # (copied verbatim from deploy/ios_demo/Podfile)
  s.pod_target_xcconfig = {
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER' => 'NO',

    # C++17 is required by ORTProfilingBridge.mm (uses std::optional<Ort::Session>)
    # and Clipper1 (uses C++17 features). The Runner template's default
    # `CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x"` (~C++11) lacks std::optional
    # and rejects throw() in typedefs from onnxruntime_c_api.h. Override here
    # so this pod's ObjC++ runtime compiler invocation is gnu++17.
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu11',

    # Clipper1 header search path so ObjC++ bridges can #include "clipper.hpp".
    # Use $(PODS_TARGET_SRCROOT) — it resolves to `Pods/../.symlinks/plugins/
    # paddle_ocr_native/ios` → the plugin's `ios/` directory. `$(PODS_ROOT)/
    # paddle_ocr_native` would resolve to a non-existent directory under `Pods/`
    # (the plugin ships as a symlink, not a copied folder).
    # clipper.hpp lives directly in `Classes/ThirdParty/Clipper1/` (no `cpp/`
    # subdirectory) so we point at `Classes/ThirdParty/Clipper1`.
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Classes/ThirdParty/Clipper1"',
  }

  # Privacy manifest contains no tracking, collection, or required-reason APIs.
  s.resource_bundles = {
    'paddle_ocr_native_privacy' => ['Classes/PrivacyInfo.xcprivacy']
  }
end
