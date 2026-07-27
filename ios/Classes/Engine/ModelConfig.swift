// Copyright (c) 2026 PaddlePaddle Authors. All Rights Reserved.
// Copyright (c) 2026 flespark contributors. Licensed under the Apache License, Version 2.0.
//
// **PADDLE_OCR_NATIVE LOCAL FORK** of upstream deploy/ios_demo/PaddleOCRDemo/Engine/ModelConfig.swift
//   — adds Flutter asset-path override so this plugin can load the PP-OCRv6_small
//     models shipped via the plugin's `flutter: assets:` directory, rather than
//     relying on the demo's `PaddleOCRDemo/Models/` bundle folder reference.
//
// Re-applied after `scripts/vendor_ios_demo_engine.sh` checkout (see PATCH STEP).
// To upgrade ModelConfig properly: diff upstream ModelConfig.swift against this
// file, fold in upstream semantic changes, then commit. README records the fork.
//
// Functional difference from upstream:
//   - Adds `static var flutterModelsDirectory: URL?` (default nil).
//   - `detection()` / `recognition()` honor that directory when set, mapping
//     `Models/det` and `Models/rec` subdirectories to `<flutterModelsDirectory>/
//     Models/{det,rec}/{inference.(ort|onnx),inference.yml}`. The plugin
//     copies Flutter asset files into `<tmp>/PaddleOCRModels/Models/{det,rec}/`
//     at init time, then sets `ModelConfig.flutterModelsDirectory` to
//     `<tmp>/PaddleOCRModels` before `ORTSessionManager.loadModels(...)`.
//   - When `flutterModelsDirectory == nil`, behavior matches upstream exactly.

import Foundation

struct ModelConfig {
    let modelPath: String
    let configPath: String
    /// From `Global.model_name` in the model config file (same directory as the ONNX weights).
    let name: String

    // MARK: - Flutter asset override hook

    /// When non-nil, `detection()` / `recognition()` resolve weights + YAML from
    /// `<flutterModelsDirectory>/Models/{det,rec}/` instead of the app bundle.
    /// The Flutter plugin sets this to a NSTemporaryDirectory subdirectory
    /// populated from `flutter_assets/packages/paddle_ocr_native/assets/models/...`
    /// before calling `ORTSessionManager.loadModels(...)`.
    static var flutterModelsDirectory: URL?

    private static func displayName(fromModelConfigPath configPath: String, fallback: String) -> String {
        guard let cfg = try? InferenceConfig.load(from: configPath) else {
            return fallback
        }
        return cfg.modelName
    }

    private static let ortResourceStems: [String] = [
        "inference",
        "inference.with_runtime_opt",
    ]

    private static func bundledOrtPath(inDirectory directory: String) -> String? {
        for stem in ortResourceStems {
            if let p = Bundle.main.path(forResource: stem, ofType: "ort", inDirectory: directory) {
                return p
            }
        }
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ort", subdirectory: directory) else {
            return nil
        }
        let matches = urls.filter { url in
            let c = url.lastPathComponent
            return c.hasPrefix("inference") && c.hasSuffix(".ort")
        }
        guard !matches.isEmpty else { return nil }
        if matches.count == 1 { return matches[0].path }
        return matches.sorted { $0.lastPathComponent < $1.lastPathComponent }.first?.path
    }

    private static func bundledWeightsPath(inDirectory directory: String, notFoundMessage: String) throws -> String {
        if let ort = bundledOrtPath(inDirectory: directory) {
            return ort
        }
        if let onnx = Bundle.main.path(forResource: "inference", ofType: "onnx", inDirectory: directory) {
            return onnx
        }
        throw ModelConfigError.modelNotFound(notFoundMessage)
    }

    // MARK: - Flutter asset override resolution

    /// Resolves weights and YAML from `<flutterModelsDirectory>/Models/<subdir>/`.
    /// Prefers `.ort` (upstream ordering), falls back to `.onnx` then `.yml`.
    private static func flutterResolve(
        subdir: String,
        fallbackName: String
    ) throws -> ModelConfig {
        guard let base = flutterModelsDirectory else {
            throw ModelConfigError.modelNotFound("flutterModelsDirectory not set")
        }
        let dir = base.appendingPathComponent("Models/\(subdir)", isDirectory: true)
        // Prefer .ort over .onnx — same precedence rule as upstream.
        let ortCandidates = ortResourceStems.map { dir.appendingPathComponent("\($0).ort") }
        let onnxFallback = dir.appendingPathComponent("inference.onnx")

        let weightsURL: URL
        if let ort = ortCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            weightsURL = ort
        } else if FileManager.default.fileExists(atPath: onnxFallback.path) {
            weightsURL = onnxFallback
        } else {
            throw ModelConfigError.modelNotFound(
                "No inference.(ort|onnx) under \(dir.path) (flutter override)"
            )
        }

        let ymlURL = dir.appendingPathComponent("inference.yml")
        guard FileManager.default.fileExists(atPath: ymlURL.path) else {
            throw ModelConfigError.modelNotFound("inference.yml under \(dir.path) (flutter override)")
        }
        let displayName = displayName(fromModelConfigPath: ymlURL.path, fallback: fallbackName)
        return ModelConfig(modelPath: weightsURL.path, configPath: ymlURL.path, name: displayName)
    }

    static func detection() throws -> ModelConfig {
        if ModelConfig.flutterModelsDirectory != nil {
            return try flutterResolve(subdir: "det", fallbackName: "text_detection")
        }
        let modelPath = try Self.bundledWeightsPath(
            inDirectory: "Models/det",
            notFoundMessage: "det/inference.ort or det/inference.onnx"
        )
        guard let configPath = Bundle.main.path(forResource: "inference", ofType: "yml", inDirectory: "Models/det") else {
            throw ModelConfigError.modelNotFound("det model config file")
        }
        let name = displayName(fromModelConfigPath: configPath, fallback: "text_detection")
        return ModelConfig(modelPath: modelPath, configPath: configPath, name: name)
    }

    static func recognition() throws -> ModelConfig {
        if ModelConfig.flutterModelsDirectory != nil {
            return try flutterResolve(subdir: "rec", fallbackName: "text_recognition")
        }
        let modelPath = try Self.bundledWeightsPath(
            inDirectory: "Models/rec",
            notFoundMessage: "rec/inference.ort or rec/inference.onnx"
        )
        guard let configPath = Bundle.main.path(forResource: "inference", ofType: "yml", inDirectory: "Models/rec") else {
            throw ModelConfigError.modelNotFound("rec model config file")
        }
        let name = displayName(fromModelConfigPath: configPath, fallback: "text_recognition")
        return ModelConfig(modelPath: modelPath, configPath: configPath, name: name)
    }
}

enum ModelConfigError: LocalizedError {
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Model file not found in bundle: \(path)"
        }
    }
}
