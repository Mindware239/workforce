package com.example.workforce

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat

import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel

class LocationTrackingService : Service() {

    companion object {
        const val CHANNEL_ID = "workforce_location_tracking"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START =
            "com.example.workforce.START_LOCATION_TRACKING"

        const val ACTION_STOP =
            "com.example.workforce.STOP_LOCATION_TRACKING"

        private const val TAG = "WorkforceLocation"
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient

    private lateinit var locationCallback: LocationCallback

    private var flutterEngine: FlutterEngine? = null

    private var backgroundChannel: MethodChannel? = null

    private var isTracking = false

    override fun onCreate() {
        super.onCreate()

        android.util.Log.d(TAG, "========================================")
        android.util.Log.d(TAG, "📍 LocationTrackingService CREATED")
        android.util.Log.d(TAG, "========================================")

        createNotificationChannel()

        fusedLocationClient =
            LocationServices.getFusedLocationProviderClient(this)

        locationCallback =
            object : LocationCallback() {

                override fun onLocationResult(
                    result: LocationResult
                ) {
                    android.util.Log.d(
                        TAG,
                        "📍 Location callback received: ${result.locations.size} location(s)"
                    )

                    for (location in result.locations) {
                        sendLocationToBackgroundIsolate(location)
                    }
                }
            }
    }

    /**
     * Creates a second FlutterEngine dedicated to the
     * background location Dart isolate.
     *
     * IMPORTANT:
     * Do NOT call GeneratedPluginRegistrant.registerWith(engine)
     * here. Flutter plugins are already registered by the embedding
     * and manually registering them causes duplicate registration.
     */
    private fun createBackgroundFlutterEngine() {

        if (flutterEngine != null) {
            android.util.Log.d(
                TAG,
                "⚠️ Background FlutterEngine already exists."
            )
            return
        }

        android.util.Log.d(
            TAG,
            "🚀 Creating background FlutterEngine..."
        )

        val flutterLoader = FlutterLoader()

        flutterLoader.startInitialization(this)

        flutterLoader.ensureInitializationComplete(
            this,
            null
        )

        val engine = FlutterEngine(this)

        val dartEntrypoint =
            DartExecutor.DartEntrypoint(
                flutterLoader.findAppBundlePath(),
                "locationBackgroundEntryPoint"
            )

        android.util.Log.d(
            TAG,
            "🚀 Starting Dart entrypoint: locationBackgroundEntryPoint"
        )

        backgroundChannel =
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "workforce/location_background"
            )

        engine.dartExecutor.executeDartEntrypoint(
            dartEntrypoint
        )

        flutterEngine = engine

        android.util.Log.d(
            TAG,
            "✅ Background FlutterEngine created."
        )
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        android.util.Log.d(
            TAG,
            "📡 onStartCommand action=${intent?.action}"
        )

        when (intent?.action) {

            ACTION_START -> {

                android.util.Log.d(
                    TAG,
                    "▶️ START_LOCATION_TRACKING received"
                )

                startForegroundService()

                if (flutterEngine == null) {
                    createBackgroundFlutterEngine()
                }

                startLocationUpdates()
            }

            ACTION_STOP -> {

                android.util.Log.d(
                    TAG,
                    "⏹ STOP_LOCATION_TRACKING received"
                )

                stopLocationUpdates()

                destroyBackgroundFlutterEngine()

                if (Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.N
                ) {
                    stopForeground(
                        STOP_FOREGROUND_REMOVE
                    )
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }

                stopSelf()
            }
        }

        /*
         * START_STICKY tells Android that this is a long-running
         * foreground service and it may recreate the service after
         * the process is killed.
         */
        return START_STICKY
    }

    /**
     * Starts the Android foreground notification.
     */
    private fun startForegroundService() {

        val notification: Notification =
            NotificationCompat.Builder(
                this,
                CHANNEL_ID
            )
                .setContentTitle(
                    "Workforce location tracking"
                )
                .setContentText(
                    "Your work location is being tracked."
                )
                .setSmallIcon(
                    android.R.drawable.ic_menu_mylocation
                )
                .setOngoing(true)
                .setPriority(
                    NotificationCompat.PRIORITY_LOW
                )
                .setCategory(
                    NotificationCompat.CATEGORY_SERVICE
                )
                .build()

        if (Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.Q
        ) {

            startForeground(
                NOTIFICATION_ID,
                notification
            )

        } else {

            startForeground(
                NOTIFICATION_ID,
                notification
            )
        }

        android.util.Log.d(
            TAG,
            "🔔 Foreground notification started."
        )
    }

    /**
     * Starts GPS updates.
     */
    private fun startLocationUpdates() {

        if (isTracking) {
            android.util.Log.d(
                TAG,
                "⚠️ Location tracking already running."
            )
            return
        }

        val fineLocationGranted =
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

        val coarseLocationGranted =
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

        if (!fineLocationGranted &&
            !coarseLocationGranted
        ) {

            android.util.Log.e(
                TAG,
                "❌ Location permission not granted."
            )

            return
        }

        val request =
            LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                30_000L
            )
                .setMinUpdateIntervalMillis(
                    15_000L
                )
                .setMinUpdateDistanceMeters(
                    25f
                )
                .setWaitForAccurateLocation(
                    true
                )
                .build()

        try {

            fusedLocationClient.requestLocationUpdates(
                request,
                locationCallback,
                Looper.getMainLooper()
            )

            isTracking = true

            android.util.Log.d(
                TAG,
                "✅ GPS location updates started."
            )
            android.util.Log.d(
                TAG,
                "⏱ Interval: 30 seconds"
            )
            android.util.Log.d(
                TAG,
                "📏 Minimum distance: 25 meters"
            )

        } catch (e: Exception) {

            android.util.Log.e(
                TAG,
                "❌ Failed to start location updates.",
                e
            )
        }
    }

    /**
     * Stops GPS updates.
     */
    private fun stopLocationUpdates() {

        if (!::fusedLocationClient.isInitialized ||
            !::locationCallback.isInitialized
        ) {
            return
        }

        try {

            fusedLocationClient.removeLocationUpdates(
                locationCallback
            )

            isTracking = false

            android.util.Log.d(
                TAG,
                "⏹ GPS location updates stopped."
            )

        } catch (e: Exception) {

            android.util.Log.e(
                TAG,
                "❌ Failed to stop location updates.",
                e
            )
        }
    }

    /**
     * Sends native Android GPS location to the
     * background Dart isolate.
     */
    private fun sendLocationToBackgroundIsolate(
        location: android.location.Location
    ) {

        val recordedAt =
            if (location.time > 0) {
                java.time.Instant
                    .ofEpochMilli(location.time)
                    .toString()
            } else {
                java.time.Instant
                    .now()
                    .toString()
            }

        val data =
            mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to location.accuracy.toDouble(),
                "speed" to location.speed.toDouble(),
                "heading" to location.bearing.toDouble(),
                "recordedAt" to recordedAt
            )

        android.util.Log.d(
            TAG,
            "📍 Native location:"
        )

        android.util.Log.d(
            TAG,
            "   lat=${location.latitude}"
        )

        android.util.Log.d(
            TAG,
            "   lng=${location.longitude}"
        )

        android.util.Log.d(
            TAG,
            "   accuracy=${location.accuracy}"
        )

        android.util.Log.d(
            TAG,
            "   recordedAt=$recordedAt"
        )

        val channel = backgroundChannel

        if (channel == null) {

            android.util.Log.e(
                TAG,
                "❌ Background MethodChannel is null."
            )

            return
        }

        try {

            channel.invokeMethod(
                "locationUpdate",
                data
            )

            android.util.Log.d(
                TAG,
                "📡 Location sent to Dart background isolate."
            )

        } catch (e: Exception) {

            android.util.Log.e(
                TAG,
                "❌ Failed to send location to Dart isolate.",
                e
            )
        }
    }

    /**
     * Creates notification channel for Android 8+.
     */
    private fun createNotificationChannel() {

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            val channel =
                NotificationChannel(
                    CHANNEL_ID,
                    "Workforce Location",
                    NotificationManager.IMPORTANCE_LOW
                )

            channel.description =
                "Keeps Workforce live location tracking active."

            val manager =
                getSystemService(
                    NotificationManager::class.java
                )

            manager.createNotificationChannel(
                channel
            )
        }
    }

    /**
     * Completely destroys the background FlutterEngine.
     */
    private fun destroyBackgroundFlutterEngine() {

        try {

            backgroundChannel = null

            flutterEngine?.destroy()

            flutterEngine = null

            android.util.Log.d(
                TAG,
                "🗑️ Background FlutterEngine destroyed."
            )

        } catch (e: Exception) {

            android.util.Log.e(
                TAG,
                "❌ Error destroying background FlutterEngine.",
                e
            )

            flutterEngine = null
            backgroundChannel = null
        }
    }

    override fun onDestroy() {

        android.util.Log.d(
            TAG,
            "💀 LocationTrackingService DESTROYED"
        )

        stopLocationUpdates()

        destroyBackgroundFlutterEngine()

        super.onDestroy()
    }

    override fun onBind(
        intent: Intent?
    ): IBinder? = null
}