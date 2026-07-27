// Copyright (c) 2026 flespark contributors. Licensed under Apache-2.0.
// Flutter MethodChannel bridge between Dart and PaddleOCR PP-OCRv6.
package com.flespark.paddle_ocr_native

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.paddle.ocr.EngineConfig
import com.paddle.ocr.PaddleOCR
import com.paddle.ocr.PaddleOCRConfig
import com.paddle.ocr.model.OCRError
import com.paddle.ocr.util.OpenCVUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

class PaddleOcrNativePlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    private var paddleOcr: PaddleOCR? = null

    // Single supervisor scope for engine init / recognize / release. Each
    // MethodChannel callback is synchronous on the platform thread; we hop to
    // Dispatchers.IO for the real work and resume the Result there.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "paddle_ocr_native")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "recognize" -> handleRecognize(call, result)
            "release" -> handleRelease(result)
            else -> result.notImplemented()
        }
    }

    // ---- init --------------------------------------------------------------

    @Suppress("UNCHECKED_CAST")
    private fun handleInit(call: MethodCall, result: Result) {
        if (paddleOcr != null) {
            result.success(mapOf("success" to true, "alreadyInitialized" to true))
            return
        }

        val configMap = call.argument<Map<String, Any>>("config") ?: emptyMap()
        val engineMap = call.argument<Map<String, Any>>("engine") ?: emptyMap()
        val config = buildConfig(configMap)
        val engine = EngineConfig(
            numThreads = (engineMap["numThreads"] as? Number)?.toInt() ?: 4,
        )

        // Flutter merges plugin assets under flutter_assets/<pkg>/...; the
        // Kotlin SDK reads them via context.assets.open(assetPath), so we can
        // hand the full asset key straight through (no cache copy needed).
        val detAsset = "flutter_assets/packages/paddle_ocr_native/assets/models/det/inference.onnx"
        val recAsset = "flutter_assets/packages/paddle_ocr_native/assets/models/rec/inference.onnx"
        val ymlAsset = "flutter_assets/packages/paddle_ocr_native/assets/models/rec/inference.yml"

        scope.launch {
            try {
                Log.i(TAG, "init: config=$config, engine=$engine, det=$detAsset")
                // OpenCV native lib must be loaded before any Mat operation.
                // The SDK's BitmapUtils.bitmapToBGRMat would crash otherwise.
                // System.loadLibrary is thread-safe; no need to pin to Main.
                if (!OpenCVUtils.init(context)) {
                    throw RuntimeException("OpenCV native lib failed to load")
                }
                val ocr = PaddleOCR.create(
                    context = context,
                    config = config,
                    engineConfig = engine,
                    detModelAssetPath = detAsset,
                    recModelAssetPath = recAsset,
                    recConfigAssetPath = ymlAsset,
                )
                paddleOcr = ocr
                Log.i(TAG, "init: ok, coldLoad=${ocr.coldLoadTimeMs}ms")
                result.success(
                    mapOf(
                        "success" to true,
                        "coldLoadTimeMs" to ocr.coldLoadTimeMs,
                    )
                )
            } catch (e: Throwable) {
                Log.e(TAG, "init failed", e)
                val code = when (e) {
                    is OCRError.ModelNotFound,
                    is OCRError.ModelLoadFailed,
                    is OCRError.ConfigParseFailed -> "MODEL_LOAD_FAILED"
                    else -> "INIT_FAILED"
                }
                result.error(code, e.message, null)
            }
        }
    }

    // ---- recognize ---------------------------------------------------------

    private fun handleRecognize(call: MethodCall, result: Result) {
        val ocr = paddleOcr
        if (ocr == null) {
            result.error("NOT_INITIALIZED", "Engine not loaded; call init first", null)
            return
        }

        val imagePath = call.argument<String>("imagePath")
        if (imagePath == null) {
            result.error("INVALID_ARGS", "imagePath required", null)
            return
        }
        scope.launch {
            try {
                val bitmap = withContext(Dispatchers.IO) { decodeBitmap(imagePath) }
                    ?: return@launch result.error(
                        "DECODE_FAILED", "Cannot decode image: $imagePath", null
                    )

                val run = try {
                    ocr.recognize(bitmap)
                } finally {
                    bitmap.recycle()
                }
                val regions = serialize(run)
                val payload = mapOf(
                    "results" to regions,
                    "detectionTimeMs" to run.detectionTimeMs,
                    "recognitionTimeMs" to run.recognitionTimeMs,
                )
                Log.i(
                    TAG,
                    "recognize: ${run.lineCount} regions, " +
                        "det=${run.detectionTimeMs}ms rec=${run.recognitionTimeMs}ms"
                )
                result.success(payload)
            } catch (e: Throwable) {
                Log.e(TAG, "recognize failed", e)
                result.error("RECOGNIZE_FAILED", e.message, null)
            }
        }
    }

    // ---- release -----------------------------------------------------------

    private fun handleRelease(result: Result) {
        val ocr = paddleOcr
        if (ocr == null) {
            result.success(true)
            return
        }
        scope.launch {
            try {
                ocr.release()
            } catch (e: Throwable) {
                Log.w(TAG, "release error: ${e.message}")
            }
            paddleOcr = null
            result.success(true)
        }
    }

    // ---- helpers -----------------------------------------------------------

    private fun decodeBitmap(path: String): Bitmap? {
        val bmp = BitmapFactory.decodeFile(path) ?: return null
        // SDK preprocessors expect ARGB_8888; ensure we don't hand back a
        // hardware/config it can't read pixels from.
        return if (bmp.config == Bitmap.Config.ARGB_8888) bmp
        else bmp.copy(Bitmap.Config.ARGB_8888, true).also { bmp.recycle() }
    }

    /** Build the Kotlin SDK PaddleOCRConfig from the Dart-side Map. */
    @Suppress("UNCHECKED_CAST")
    private fun buildConfig(m: Map<String, Any>): PaddleOCRConfig {
        return PaddleOCRConfig(
            detLimitSideLen = intArg(m, "detLimitSideLen", 960),
            detLimitType = (m["detLimitType"] as? String) ?: "max",
            detMaxSideLimit = intArg(m, "detMaxSideLimit", 4000),
            detThresh = floatArg(m, "detThresh", 0.3f),
            detBoxThresh = floatArg(m, "detBoxThresh", 0.6f),
            detUnclipRatio = floatArg(m, "detUnclipRatio", 1.5f),
            recScoreThresh = floatArg(m, "recScoreThresh", 0.0f),
            recBatchSize = intArg(m, "recBatchSize", 6),
        )
    }

    private fun intArg(m: Map<String, Any>, key: String, default: Int): Int =
        (m[key] as? Number)?.toInt() ?: default

    private fun floatArg(m: Map<String, Any>, key: String, default: Float): Float =
        (m[key] as? Number)?.toFloat() ?: default

    private fun serialize(run: com.paddle.ocr.model.OCRRunResult): List<Map<String, Any>> {
        return run.results.map { r ->
            val points = r.box.points.map { p ->
                mapOf("x" to Math.round(p.x).toInt(), "y" to Math.round(p.y).toInt())
            }
            mapOf(
                "text" to r.text,
                "confidence" to r.confidence.toDouble(),
                "points" to points,
                "clsLabel" to -1,
                "clsScore" to 0.0,
            )
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Best-effort release of native resources on engine teardown.
        paddleOcr?.let { ocr ->
            runBlocking { runCatching { ocr.release() } }
            paddleOcr = null
        }
        (scope.coroutineContext[Job])?.cancel()
    }

    companion object {
        private const val TAG = "PaddleOcrNative"
    }
}
