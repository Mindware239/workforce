package com.mindware.workforce

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

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

                "openGoogleMaps" -> {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    val label = call.argument<String>("label") ?: "Client"
                    val address = call.argument<String>("address")
                    result.success(openGoogleMapsDirectly(lat, lng, label, address))
                }

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

    /**
     * Directly launches Google Maps (com.google.android.apps.maps) to display the destination pin,
     * bypassing third-party delivery apps like Porter, Rapido, or Uber that register geo intents.
     * Drops the location pin directly on the map so Google Maps doesn't fail with "Walk - Something went wrong".
     */
    private fun openGoogleMapsDirectly(lat: Double?, lng: Double?, label: String, address: String?): Boolean {
        val mapsPackage = "com.google.android.apps.maps"
        val hasCoords = lat != null && lng != null && lat != 0.0 && lng != 0.0

        try {
            // 1. Drop a Pin on the client location specifically inside Google Maps
            val query = if (hasCoords) {
                "$lat,$lng($label)"
            } else if (!address.isNullOrBlank()) {
                address
            } else {
                label
            }

            val geoUri = Uri.parse("geo:0,0?q=" + Uri.encode(query))
            val geoIntent = Intent(Intent.ACTION_VIEW, geoUri).apply {
                setPackage(mapsPackage)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            if (geoIntent.resolveActivity(packageManager) != null) {
                startActivity(geoIntent)
                return true
            }

            // 2. Official Google Maps Search / Location Pin URL specifically targeting Google Maps app
            val webQuery = if (hasCoords) "$lat,$lng" else (address ?: label)
            val webUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=" + Uri.encode(webQuery))
            val webIntent = Intent(Intent.ACTION_VIEW, webUri).apply {
                setPackage(mapsPackage)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            if (webIntent.resolveActivity(packageManager) != null) {
                startActivity(webIntent)
                return true
            }

            // 3. Driving Navigation Intent (mode=d) targeting Google Maps
            if (hasCoords) {
                val navUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
                val navIntent = Intent(Intent.ACTION_VIEW, navUri).apply {
                    setPackage(mapsPackage)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                if (navIntent.resolveActivity(packageManager) != null) {
                    startActivity(navIntent)
                    return true
                }
            }

            // 4. Universal Fallback
            val fallbackIntent = Intent(Intent.ACTION_VIEW, webUri).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(fallbackIntent)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}
