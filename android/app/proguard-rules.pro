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
# CRITICAL: Maven coordinates are io.github.junkfood02.youtubedl-android, but the
# actual Kotlin/Java packages are com.yausername.*. The previous rules kept
# org.yausername.** and io.github.junkfood02.youtubedl.** which never matched,
# so R8 stripped/renamed the library and release builds crashed with
# NoClassDefFoundError / ClassNotFoundException whose message was an obfuscated
# name like "I4.f" (surfaced to users as "Platform error: I4.f").
-keep class com.yausername.** { *; }
-keep class io.github.junkfood02.** { *; }
-dontwarn com.yausername.**
-dontwarn io.github.junkfood02.**

# youtubedl-android depends on Apache Commons IO + Commons Compress at runtime
# (ZipUtils.unzip → org.apache.commons.compress.archivers.zip.*). Stripping
# Compress caused NoClassDefFoundError during YoutubeDL.initPython().
-keep class org.apache.commons.io.** { *; }
-keep class org.apache.commons.compress.** { *; }
-dontwarn org.apache.commons.io.**
-dontwarn org.apache.commons.compress.**

# Keep exception class names and messages readable in release stack traces.
# Without this, Error.message is often just an obfuscated class name.
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions,*Annotation*,Signature,InnerClasses,EnclosingMethod
-renamesourcefileattribute SourceFile
-keep class * extends java.lang.Throwable { *; }

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

# Missing Java Beans classes (referenced by Jackson)
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient

# Jackson
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

# flutter_local_notifications uses Gson TypeToken to restore scheduled
# notifications. R8 removes generic signatures by default, which makes Gson
# throw "TypeToken must be created with a type argument" in release builds.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
