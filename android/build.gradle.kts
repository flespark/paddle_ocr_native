// Flutter 3.44+ uses AGP 9 built-in Kotlin support. The host app owns plugin
// versions; this library only applies the Android library plugin.
group = "com.flespark.paddle_ocr_native"
version = "1.0-SNAPSHOT"

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.flespark.paddle_ocr_native"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main").java.srcDirs(
            "src/main/kotlin",
            // Vendored official PaddleOCR ppocr-sdk (Kotlin, Apache-2.0).
            // See doc/upstream.md for provenance and upgrade instructions.
            "ppocr-sdk/src/main/java",
        )
    }

    defaultConfig {
        // ppocr-sdk requires minSdk 26 (ONNX Runtime 1.21 + OpenCV 4.5.3).
        minSdk = 26
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // SDK runtime deps (merged into the plugin's own deps since we compile the
    // SDK sources directly now). Versions match upstream ppocr-sdk EXCEPT
    // OpenCV: upstream uses com.quickbirdstudios:opencv:4.5.3 which is
    // unmaintained (last release 2021) and its prebuilt libopencv_java4.so
    // references the private libc symbol __sfp_handle_exceptions, causing
    // `dlopen failed: cannot locate symbol` on Android 14+/API 34+ stricter
    // linker namespaces (V2419A = API 35). The official org.opencv:opencv
    // Maven artifact (built with a modern NDK) is a drop-in replacement —
    // same package names, same libopencv_java4.so ABI — so the vendored SDK
    // sources need no changes.
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.28.0")
    implementation("org.opencv:opencv:4.13.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("androidx.core:core-ktx:1.13.1")
}
