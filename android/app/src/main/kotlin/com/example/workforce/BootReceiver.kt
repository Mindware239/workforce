package com.example.workforce

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Resumes location tracking after a reboot or app update if the
 * employee was still checked in.
 *
 * Starting a location foreground service from here requires
 * "Allow all the time" (background) location permission.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (
                    LocationTrackingService.isTrackingActive(context) &&
                    LocationTrackingService
                        .hasBackgroundLocationPermission(context)
                ) {
                    LocationTrackingService.start(context)
                }
            }
        }
    }
}
