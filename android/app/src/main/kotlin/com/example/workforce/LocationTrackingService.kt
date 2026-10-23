package com.mindware.workforce

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that keeps location tracking alive while the
 * employee is checked in, including after the app is swiped away,
 * the process is killed by the system, or the device reboots.
 */
class LocationTrackingService : Service() {

    companion object {
        const val CHANNEL_ID = "workforce_location_tracking"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START =
            "com.mindware.workforce.START_LOCATION_TRACKING"

        const val ACTION_STOP =
            "com.mindware.workforce.STOP_LOCATION_TRACKING"

        private const val TAG = "WorkforceLocation"

        private const val PREFS = "workforce_location_tracking"
        private const val KEY_ACTIVE = "tracking_active"

        private const val INTERVAL_MS = 30_000L
        private const val MIN_INTERVAL_MS = 15_000L
        private const val MIN_DISTANCE_M = 25f

        // A fix within this is real GPS. Indoors the fused provider mixes in
        // cell/Wi-Fi estimates (100-400 m) placed at the tower, which would
        // move the employee's pin hundreds of metres while they sit still.
        private const val PRECISE_ACCURACY_M = 30f

        // Coarse fixes are dropped only while GPS is working. After this long
        // without a precise fix, they are sent so the employee still shows up.
        private const val COARSE_FALLBACK_MS = 5 * 60_000L

        fun hasLocationPermission(context: Context): Boolean =
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED

        fun hasBackgroundLocationPermission(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == PackageManager.PERMISSION_GRANTED

        /** Whether the employee is checked in and tracking should run. */
        fun isTrackingActive(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_ACTIVE, false)

        private fun setTrackingActive(context: Context, active: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ACTIVE, active)
                .apply()
        }

        /** Returns false when location permission is missing. */
        fun start(context: Context): Boolean {
            if (!hasLocationPermission(context)) {
                Log.w(TAG, "Not starting: location permission missing.")
                return false
            }

            setTrackingActive(context, true)

            val intent = Intent(context, LocationTrackingService::class.java)
                .setAction(ACTION_START)

            return try {
                ContextCompat.startForegroundService(context, intent)
                true
            } catch (e: Exception) {
                // e.g. ForegroundServiceStartNotAllowedException when
                // started from the background without permission.
                Log.e(TAG, "Failed to start tracking service.", e)
                false
            }
        }

        fun stop(context: Context) {
            setTrackingActive(context, false)

            context.stopService(
                Intent(context, LocationTrackingService::class.java)
            )
        }
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient

    private val locationCallback =
        object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.locations.forEach(::handleLocation)
            }
        }

    private var lastPreciseFixAt = 0L

    private fun handleLocation(location: Location) {
        val now = System.currentTimeMillis()

        if (location.hasAccuracy() && location.accuracy <= PRECISE_ACCURACY_M) {
            lastPreciseFixAt = now
            sendLocationToBackgroundIsolate(location)
            return
        }

        if (now - lastPreciseFixAt < COARSE_FALLBACK_MS) {
            Log.d(TAG, "Skipping coarse fix (accuracy ${location.accuracy} m).")
            return
        }

        sendLocationToBackgroundIsolate(location)
    }

    private var flutterEngine: FlutterEngine? = null

    private var backgroundChannel: MethodChannel? = null

    private var isTracking = false

    override fun onCreate() {
        super.onCreate()

        createNotificationChannel()

        fusedLocationClient =
            LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        if (intent?.action == ACTION_STOP) {
            stop(this)
            return START_NOT_STICKY
        }

        // A null intent means Android restarted the sticky service
        // after killing the process. Only resume if still checked in.
        if (!isTrackingActive(this) || !hasLocationPermission(this)) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (!startAsForeground()) {
            stopSelf()
            return START_NOT_STICKY
        }

        createBackgroundFlutterEngine()

        startLocationUpdates()

        return START_STICKY
    }

    /**
     * Promotes the service to the foreground with the "location" type,
     * which Android 14+ requires.
     */
    private fun startAsForeground(): Boolean {
        val launchIntent =
            packageManager.getLaunchIntentForPackage(packageName)

        val contentIntent =
            launchIntent?.let {
                PendingIntent.getActivity(
                    this,
                    0,
                    it,
                    PendingIntent.FLAG_IMMUTABLE or
                        PendingIntent.FLAG_UPDATE_CURRENT
                )
            }

        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Workforce location tracking")
                .setContentText("Your work location is being tracked.")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setForegroundServiceBehavior(
                    NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE
                )
                .build()

        return try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                } else {
                    0
                }
            )
            true
        } catch (e: Exception) {
            // SecurityException if location permission was revoked,
            // or the start was not allowed from the background.
            Log.e(TAG, "Unable to enter foreground.", e)
            false
        }
    }

    /**
     * Starts a second FlutterEngine that runs the Dart entrypoint
     * `locationBackgroundEntryPoint`, so location uploads work even
     * when the UI is not running. Plugins are registered automatically.
     */
    private fun createBackgroundFlutterEngine() {
        if (flutterEngine != null) return

        val loader = FlutterInjector.instance().flutterLoader()

        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val engine = FlutterEngine(applicationContext)

        backgroundChannel =
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "workforce/location_background"
            )

        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "locationBackgroundEntryPoint"
            )
        )

        flutterEngine = engine
    }

    private fun startLocationUpdates() {
        if (isTracking) return

        val request =
            LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                INTERVAL_MS
            )
                .setMinUpdateIntervalMillis(MIN_INTERVAL_MS)
                .setMinUpdateDistanceMeters(MIN_DISTANCE_M)
                .setWaitForAccurateLocation(true)
                .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                request,
                locationCallback,
                Looper.getMainLooper()
            )

            isTracking = true
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission revoked.", e)
            stopSelf()
        }
    }

    private fun stopLocationUpdates() {
        if (!isTracking) return

        fusedLocationClient.removeLocationUpdates(locationCallback)

        isTracking = false
    }

    /** Sends a GPS fix to the background Dart isolate. */
    private fun sendLocationToBackgroundIsolate(location: Location) {
        val recordedAt =
            java.time.Instant.ofEpochMilli(
                if (location.time > 0) location.time
                else System.currentTimeMillis()
            ).toString()

        val data =
            mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to location.accuracy.toDouble(),
                "speed" to location.speed.toDouble(),
                "heading" to location.bearing.toDouble(),
                "recordedAt" to recordedAt
            )

        try {
            backgroundChannel?.invokeMethod("locationUpdate", data)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send location to Dart isolate.", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Workforce Location",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description =
                    "Keeps Workforce live location tracking active."
            }

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun destroyBackgroundFlutterEngine() {
        backgroundChannel = null

        try {
            flutterEngine?.destroy()
        } catch (e: Exception) {
            Log.e(TAG, "Error destroying background FlutterEngine.", e)
        }

        flutterEngine = null
    }

    override fun onDestroy() {
        stopLocationUpdates()

        destroyBackgroundFlutterEngine()

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
