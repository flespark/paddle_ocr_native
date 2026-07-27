# paddle_ocr_native 中文指南

`paddle_ocr_native` 是一个面向 Flutter Android 与 iOS 的离线 OCR 插件，
使用 PaddleOCR PP-OCRv6 small、ONNX Runtime 和 OpenCV，在设备本地完成
文字检测与识别。图片不会上传，运行时不依赖网络。

> 本项目是社区维护的独立插件，不是 PaddlePaddle 官方 Flutter package。

## 平台要求

| 平台 | 最低版本 | 架构 | 状态 |
| --- | --- | --- | --- |
| Android | API 26 | arm64-v8a | 支持 |
| iOS | iOS 16 | arm64 真机 | 支持 |
| iOS 模拟器 | - | arm64 simulator | 不支持 |
| Web/桌面 | - | - | 不支持 |

iOS 依赖的 OpenCV 4.3 不包含 Apple Silicon 模拟器 slice，因此必须使用
iOS 真机构建和测试。开发环境要求 Flutter 3.44+、Dart 3.12+、Java 17、
Android SDK 36；iOS 还需要 Xcode 16+ 和 CocoaPods。

插件 0.1.0 使用 CocoaPods，暂不支持 Flutter Swift Package Manager。Flutter
3.44 会输出兼容性提示并自动回退到 CocoaPods，这是当前版本的预期行为；宿主
项目必须保留 CocoaPods 配置。

iOS 宿主 Podfile 必须设置 `platform :ios, '16.0'`，并使用
`use_frameworks! :linkage => :static`；这是 OpenCV 4.3 静态 framework 的
链接要求。完整 `post_install` 配置可直接参考 `example/ios/Podfile`。

Android 宿主项目需在 `android/app/build.gradle.kts` 的 `defaultConfig` 中设置
`ndk { abiFilters += "arm64-v8a" }`。当前 Android Gradle Plugin 仍可能保留
传递 AAR 中的预编译 JNI 库，因此还需在 `android` 块中明确排除未支持架构：

```kotlin
packaging {
    jniLibs {
        excludes += setOf(
            "lib/armeabi-v7a/**",
            "lib/x86/**",
            "lib/x86_64/**",
        )
    }
}
```

## 安装与调用

```shell
flutter pub add paddle_ocr_native
```

```dart
import 'package:paddle_ocr_native/paddle_ocr_native.dart';

final ocr = PaddleOcr();
await ocr.init(
  config: const PaddleOcrConfig(),
  engine: const EngineConfig(numThreads: 4),
);

final run = await ocr.recognize('/absolute/path/to/image.jpg');
for (final region in run.results) {
  print('${region.text}: ${region.confidence}');
  print(region.points);
}

await ocr.dispose();
```

`PaddleOcr()` 返回进程内共享实例。初始化、识别和释放会顺序执行；重复
`init`/`dispose` 是安全的。输入必须是本地 PNG、JPEG 或 WebP 的绝对路径。

`PaddleOcrConfig` 仅暴露 Android 与 iOS 都能生效的参数。紧密排列的手写行
可尝试 `const PaddleOcrConfig.handwrittenRows()`，但任何参数调整都应在两端
真机上用代表性图片做 A/B 验证。

插件默认内置约 29 MB 的 PP-OCRv6 small ONNX 模型，安装后即可离线使用。
0.1 版本不支持运行时下载或自定义模型路径。模型来源与哈希见
[model-provenance.md](model-provenance.md)。

## 示例与验证

```shell
cd example
flutter run -d <device-id>
flutter test integration_test/ocr_smoke_test.dart -d <device-id>
```

示例支持直接识别内置开源样图或从相册选择图片，并展示文本、置信度、坐标
以及检测/识别耗时。更完整的 API、故障排查和维护说明以仓库根目录英文
[README](../README.md) 为准。
