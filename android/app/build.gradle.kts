plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aerotube.youtube_downloader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.aerotube.youtube_downloader"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // youtubedl-android ships archived payloads as *.zip.so files.
            // These are not ELF objects and must not be stripped.
            keepDebugSymbols += setOf("**/*.zip.so")
        }
    }

    splits {
        abi {
            // Decision (sideload distribution): keep isUniversalApk = true so
            // GitHub releases/android can ship one universal APK alongside the
            // per-ABI splits. ABI splits are already disabled when the Gradle
            // task name contains "bundle" (AAB / Play path).
            // Do NOT flip isUniversalApk to false unless the product switches
            // fully to Play AAB-only distribution.
            isEnable = gradle.startParameter.taskNames.none { it.contains("bundle", ignoreCase = true) }
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }

    sourceSets {
        getByName("test") {
            // Canonical Kotlin unit-test source dir (plus existing java/).
            java.srcDir("src/test/kotlin")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Kotlin Coroutines for background tasks
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // lifecycleScope for method-channel handlers (FlutterActivity is a LifecycleOwner)
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")

    // youtubedl-android library - keep current stable version
    val youtubedlAndroid = "0.18.1"
    implementation("io.github.junkfood02.youtubedl-android:library:$youtubedlAndroid")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:$youtubedlAndroid")

    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
