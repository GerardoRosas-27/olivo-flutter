# ML Kit / Barhopper — required for mobile_scanner in release (Flutter enables R8 minify by default).
# mobile_scanner's consumer rules use single-segment `com.google.mlkit.*`, which does NOT keep
# nested packages (vision.barcode.internal, etc.) and causes NPEs like:
#   Attempt to invoke virtual method '…' on a null object reference
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode_bundled.** { *; }
-keep class com.google.photos.** { *; }

# Keep Flutter plugin implementations (also covered by Flutter's rules; belt-and-suspenders).
-if class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep class <1> { *; }
