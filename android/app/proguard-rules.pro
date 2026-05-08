# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# youtubedl-android
-keep class io.github.junkfood02.youtubedl.** { *; }
-keep class org.yausername.** { *; }
-dontwarn org.yausername.**
-dontwarn io.github.junkfood02.**

# Python (for chaquopy / embedded Python)
-keep class com.chaquo.python.** { *; }
-dontwarn com.chaquo.python.**

# FileProvider
-keep class androidx.core.content.FileProvider { *; }

# Keep native method signatures
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep model classes used with Hive
-keep class com.aerotube.youtube_downloader.** { *; }

# General optimizations
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses

# Play Core splitcompat (needed for Flutter release builds)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
