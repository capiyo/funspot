package com.tech.clash

import android.os.Bundle // Add this import
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) { // Add this method
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register native ad factory - MUST match the factoryId in Dart
        try {
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                    flutterEngine,
                    "nativeAdFactory",
                    NativeAdFactory(this) // Use 'this' instead of 'context'
            )
            android.util.Log.d("MainActivity", "✅ NativeAdFactory registered successfully")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ Failed to register NativeAdFactory: ${e.message}")
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        try {
            GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeAdFactory")
            android.util.Log.d("MainActivity", "✅ NativeAdFactory unregistered")
        } catch (e: Exception) {
            android.util.Log.e(
                    "MainActivity",
                    "❌ Failed to unregister NativeAdFactory: ${e.message}"
            )
        }
    }
}
