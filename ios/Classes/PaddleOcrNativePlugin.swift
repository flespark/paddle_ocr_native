// Copyright (c) 2026 flespark contributors. Licensed under Apache-2.0.
// Flutter MethodChannel bridge between Dart and PaddleOCR PP-OCRv6.
//
//   init(config, engine) -> {success, coldLoadTimeMs}
//   recognize(imagePath) -> {results:[{text,confidence,points:[{x,y}],
//                                                clsLabel:-1,clsScore:0}],
//                                      detectionTimeMs, recognitionTimeMs}
//   release() -> true
//
// Models are loaded from this plugin's Flutter assets. Configuration is
// applied at init and reused for every recognition run.

import Flutter
import UIKit

/// MethodChannel name — kept identical to Android so Dart only declares one.
private let kChannelName = "paddle_ocr_native"

/// Tag for os_log / print-style tracing.
private let kTag = "PaddleOcrNative"

@objc public class PaddleOcrNativePlugin: NSObject, FlutterPlugin {

    // MARK: - FlutterPlugin registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: kChannelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(PaddleOcrNativePlugin(), channel: channel)
    }

    // MARK: - State

    private var sessionManager: ORTSessionManager?
    private var engine: OCREngine?
    /// Persisted config set at init — re-applied on each recognize() call as
    /// OCRRuntimeParams.
    private var runtimeParams: OCRRuntimeParams = .noOverrides
    private var initialized: Bool = false

    // MARK: - Method call dispatch

    @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            handleInit(call, result: result)
        case "recognize":
            handleRecognize(call, result: result)
        case "release":
            handleRelease(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - init

    private func handleInit(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !initialized else {
            result(["success": true, "alreadyInitialized": true])
            return
        }
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "Expected a Map of args",
                                details: nil))
            return
        }
        let configMap = args["config"] as? [String: Any] ?? [:]
        let engineMap = args["engine"] as? [String: Any] ?? [:]
        let start = CFAbsoluteTimeGetCurrent()

        Task {
            do {
                let modelsRoot = try ensureModelsCopied()
                // Set the model directory before building sessions / engines;
                // DetectionEngine / RecognitionEngine `init` reads yml via
                // ModelConfig.detection()/recognition() at construction time.
                ModelConfig.flutterModelsDirectory = modelsRoot

                self.runtimeParams = self.buildRuntimeParams(from: configMap)
                let tuning = makeTuningOptions(from: engineMap)
                let manager = ORTSessionManager()
                try await manager.loadModels(
                    executionProvider: .cpu,
                    ortProfiling: false,
                    tuning: tuning
                )
                let eng = try OCREngine(sessionManager: manager)

                self.sessionManager = manager
                self.engine = eng
                self.initialized = true

                let coldLoadMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                NSLog("[%@] init: ok coldLoad=%dms", kTag, coldLoadMs)
                result([
                    "success": true,
                    "coldLoadTimeMs": coldLoadMs,
                ])
            } catch {
                NSLog("[%@] init failed: %@", kTag, String(describing: error))
                let code = error is ModelConfigError ||
                    error is InferenceConfigError ||
                    error is ORTSessionManagerError
                    ? "MODEL_LOAD_FAILED"
                    : "INIT_FAILED"
                result(FlutterError(code: code,
                                    message: error.localizedDescription,
                                    details: nil))
            }
        }
    }

    // MARK: - recognize

    private func handleRecognize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let engine = self.engine else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "Engine not loaded; call init first",
                                details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "imagePath required",
                                details: nil))
            return
        }
        Task {
            do {
                guard let cgImage = loadCGImage(at: imagePath) else {
                    result(FlutterError(code: "DECODE_FAILED",
                                        message: "Cannot decode image: \(imagePath)",
                                        details: nil))
                    return
                }
                let run = try await engine.run(cgImage, params: self.runtimeParams)
                let payload = serialize(run)
                NSLog("[%@] recognize: %d regions det=%dms rec=%dms",
                      kTag, run.results.count,
                      Int(run.detectionTime * 1000),
                      Int(run.recognitionTime * 1000))
                result(payload)
            } catch {
                NSLog("[%@] recognize failed: %@", kTag, String(describing: error))
                result(FlutterError(code: "RECOGNIZE_FAILED",
                                    message: error.localizedDescription,
                                    details: nil))
            }
        }
    }

    // MARK: - release

    private func handleRelease(result: @escaping FlutterResult) {
        // ORTSessionManager is an actor — there is no explicit teardown API on
        // the vendored engine; dropping references allows ARC to clean up.
        self.engine = nil
        self.sessionManager = nil
        self.initialized = false
        NSLog("[%@] release: ok", kTag)
        result(true)
    }

    // MARK: - Model asset copying → NSTemporaryDirectory

    /// Copies the four model files (det/onnx, det/yml, rec/onnx, rec/yml) from the Flutter
    /// `flutter_assets` bundle (resolved via `FlutterDartProject.lookupKeyForAsset`)
    /// into `<NSTemporaryDirectory>/PaddleOCRModels/Models/{det,rec}/`. Re-uses an
    /// existing copy when all three files match in size (avoids repeated I/O).
    private func ensureModelsCopied() throws -> URL {
        let assetDir = "assets/models"
        let pluginPackage = "packages/paddle_ocr_native"

        let detAssetKey = "\(pluginPackage)/\(assetDir)/det/inference.onnx"
        let detYmlAssetKey = "\(pluginPackage)/\(assetDir)/det/inference.yml"
        let recAssetKey = "\(pluginPackage)/\(assetDir)/rec/inference.onnx"
        let ymlAssetKey = "\(pluginPackage)/\(assetDir)/rec/inference.yml"

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaddleOCRModels", isDirectory: true)
        let modelsRoot = tmp
        let detDir = tmp.appendingPathComponent("Models/det", isDirectory: true)
        let recDir = tmp.appendingPathComponent("Models/rec", isDirectory: true)
        try FileManager.default.createDirectory(
            at: detDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: recDir, withIntermediateDirectories: true)

        // Flutter assets 在 iOS 上打包到 App.framework/flutter_assets/ 下，
        // 通过 lookupKeyForAsset 拿到的 key 已是相对 Runner.app 根目录的完整路径，
        // copyAssetIfNeeded 中直接用 Bundle.main + lookupKey 拼。
        try copyAssetIfNeeded(assetKey: detAssetKey,
                              dest: detDir.appendingPathComponent("inference.onnx"))
        try copyAssetIfNeeded(assetKey: detYmlAssetKey,
                              dest: detDir.appendingPathComponent("inference.yml"))
        try copyAssetIfNeeded(assetKey: recAssetKey,
                              dest: recDir.appendingPathComponent("inference.onnx"))
        try copyAssetIfNeeded(assetKey: ymlAssetKey,
                              dest: recDir.appendingPathComponent("inference.yml"))
        return modelsRoot
    }

    private func copyAssetIfNeeded(assetKey: String, dest: URL) throws {
        // FlutterDartProject.lookupKey(forAsset:) 在 iOS 上返回的 key 已经是
        // 相对于 Runner.app 根目录的完整相对路径（如
        // "Frameworks/App.framework/flutter_assets/packages/paddle_ocr_native/.../inference.onnx"），
        // 不需要再添加任何前缀。直接用 Bundle.main.bundlePath + key 拼接即可。
        //
        // 注意：误把 key 当作 asset-only 路径再拼一次 `Frameworks/App.framework/
        // flutter_assets/` 会产生双前缀导致文件查不到。
        let key = FlutterDartProject.lookupKey(forAsset: assetKey)
        let fm = FileManager.default

        // 主要候选：Bundle.main.bundlePath + key（iOS 标准路径）
        let candidates: [URL] = [
            URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent(key),
            Bundle(for: PaddleOcrNativePlugin.self).bundleURL.appendingPathComponent(key),
        ]
        for src in candidates {
            if fm.fileExists(atPath: src.path) {
                NSLog("[%@] copyAssetIfNeeded: found asset %@ -> %@", kTag, assetKey, src.path)
                try copyIfChanged(src: src, dest: dest)
                return
            }
        }

        NSLog("[%@] copyAssetIfNeeded: FAILED for asset %@", kTag, assetKey)
        throw ModelConfigError.modelNotFound(
            "Flutter asset missing for key \(assetKey) (bundle=\(Bundle.main.bundlePath))")
    }

    private func copyIfChanged(src: URL, dest: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            if let srcSize = try? fm.attributesOfItem(atPath: src.path)[.size] as? Int,
               let destSize = try? fm.attributesOfItem(atPath: dest.path)[.size] as? Int,
               srcSize == destSize {
                return  // cache hit
            }
            try? fm.removeItem(at: dest)
        }
        try fm.copyItem(at: src, to: dest)
    }

    // MARK: - Wire serialization (mirrors Android `serialize(run)`)

    private func serialize(_ run: OCRRunResult) -> [String: Any] {
        let results: [[String: Any]] = run.results.map { r in
            let points = r.polygon.map { pt -> [String: Any] in
                // pt is [x, y] in Int32; Android rounds to Int.
                guard pt.count >= 2 else {
                    return ["x": 0, "y": 0]
                }
                return ["x": Int(pt[0]), "y": Int(pt[1])]
            }
            return [
                "text": r.text,
                "confidence": Double(r.confidence),
                "points": points,
                "clsLabel": -1,
                "clsScore": 0.0,
            ] as [String: Any]
        }
        return [
            "results": results,
            "detectionTimeMs": Int(run.detectionTime * 1000),
            "recognitionTimeMs": Int(run.recognitionTime * 1000),
        ] as [String: Any]
    }

    // MARK: - Image decoding

    private func loadCGImage(at path: String) -> CGImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    // MARK: - Config plumbing

    /// Maps the Dart-side `PaddleOcrConfig` to cross-platform runtime values.
    private func buildRuntimeParams(from m: [String: Any]) -> OCRRuntimeParams {
        var p = OCRRuntimeParams.noOverrides
        if let v = m["detLimitSideLen"] as? Int { p.textDetLimitSideLen = v }
        if let v = m["detLimitType"] as? String { p.textDetLimitType = v }
        if let v = m["detMaxSideLimit"] as? Int { p.textDetMaxSideLimit = v }
        if let v = (m["detThresh"] as? NSNumber)?.floatValue { p.textDetThresh = v }
        if let v = (m["detBoxThresh"] as? NSNumber)?.floatValue { p.textDetBoxThresh = v }
        if let v = (m["detUnclipRatio"] as? NSNumber)?.floatValue { p.textDetUnclipRatio = v }
        if let v = m["recBatchSize"] as? Int { p.textRecBatchSize = v }
        if let v = (m["recScoreThresh"] as? NSNumber)?.floatValue { p.textRecScoreThresh = v }
        return p
    }

    private func makeTuningOptions(from engineMap: [String: Any]) -> ORTSessionTuningOptions {
        var tuning = ORTSessionTuningOptions.default
        if let n = engineMap["numThreads"] as? Int, n > 0 {
            tuning.intraOpThreads = n
        }
        return tuning
    }
}
