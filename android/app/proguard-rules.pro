-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }

-keep class androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }

-dontwarn com.google.mlkit.**
-dontwarn androidx.camera.**