package com.mindware.workforce

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "workforce/location"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" ->
                    result.success(LocationTrackingService.start(this))

                "stopTracking" -> {
                    LocationTrackingService.stop(this)
                    result.success(true)
                }

                "isTracking" ->
                    result.success(
                        LocationTrackingService.isTrackingActive(this)
                    )

                else -> result.notImplemented()
            }
        }

        // Self-heal: if the employee is checked in but the service was
        // stopped (force stop, OEM battery killer), restart it now that
        // the app is in the foreground.
        if (LocationTrackingService.isTrackingActive(this)) {
            LocationTrackingService.start(this)
        }
    }
}
