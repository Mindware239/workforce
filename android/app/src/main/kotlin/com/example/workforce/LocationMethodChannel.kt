package com.example.workforce

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodChannel

object LocationMethodChannel {

    private const val CHANNEL =
        "workforce/location"

    private var methodChannel:
        MethodChannel? = null

    fun register(
        context: Context,
        channel: MethodChannel
    ) {

        methodChannel = channel

        channel.setMethodCallHandler {
                call,
                result ->

            when (call.method) {

                "startTracking" -> {

                    val intent =
                        Intent(
                            context,
                            LocationTrackingService::class.java
                        ).apply {
                            action =
                                LocationTrackingService.ACTION_START
                        }

                    if (
                        Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.O
                    ) {
                        context.startForegroundService(
                            intent
                        )
                    } else {
                        context.startService(
                            intent
                        )
                    }

                    result.success(true)
                }

                "stopTracking" -> {

                    val intent =
                        Intent(
                            context,
                            LocationTrackingService::class.java
                        ).apply {
                            action =
                                LocationTrackingService.ACTION_STOP
                        }

                    context.startService(intent)

                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    fun sendLocation(
        data: Map<String, Any>
    ) {

        methodChannel?.invokeMethod(
            "locationUpdate",
            data
        )
    }
}