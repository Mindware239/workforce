-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }

-keep class androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }

-dontwarn com.google.mlkit.**
-dontwarn androidx.camera.**

# Flutter references Play Core (deferred components) which this app doesn't use
-dontwarn com.google.android.play.core.**

# Background location service + Dart entrypoint lookup
-keep class com.example.workforce.** { *; }

# Strip verbose/debug logging from release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}
