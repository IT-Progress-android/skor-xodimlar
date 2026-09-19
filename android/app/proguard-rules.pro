# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Google ML Kit face detection (accessed via reflection / native)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-dontwarn com.google.mlkit.**

# CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
