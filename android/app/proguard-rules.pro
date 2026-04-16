# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Android Bluetooth
-keep class android.bluetooth.** { *; }
-keep class androidx.core.app.** { *; }

# Coroutines
-keep class kotlinx.coroutines.** { *; }

# BlueSnafer Pro classes
-keep class com.bluesnafer_pro.** { *; }

# Keep all classes that might be serialized/deserialized
-keep class ** implements java.io.Serializable { *; }
-keep class ** implements android.os.Parcelable { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all enum values and valueOf methods
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep all classes with @Keep annotation
-keep @androidx.annotation.Keep class * { *; }
-keep @androidx.annotation.Keep class ** { *; }

# Keep all classes with @Keep annotation members
-keepclasseswithmembernames class * {
    @androidx.annotation.Keep <methods>;
}

# Keep all classes with @Keep annotation fields
-keepclasseswithmembernames class * {
    @androidx.annotation.Keep <fields>;
}

# Suppress warnings for missing references
-dontwarn android.bluetooth.**
-dontwarn androidx.core.**
-dontwarn kotlinx.coroutines.**
-dontwarn kotlin.**
-dontwarn com.google.android.play.core.**

# Keep Google Play Core classes
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Keep Flutter Play Store classes
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Optimization rules
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify
-dontskipnonpubliclibraryclasses
-dontskipnonpubliclibraryclassmembers

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Keep line number information for debugging (remove in production)
-keepattributes SourceFile,LineNumberTable

# Keep all annotations
-keepattributes *Annotation*

# Keep inner classes
-keepattributes InnerClasses

# Keep generic signatures
-keepattributes Signature

# Keep exceptions
-keepattributes Exceptions

# Remove unused code
-whyareyoukeeping class *

# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**
