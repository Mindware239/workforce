package com.mindware.workforce

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.util.Log

/**
 * Turns an admin command name (the whitelist shared with the backend
 * device_commands table) into a device action, and returns a short result the
 * app relays back to the server as the command acknowledgement.
 *
 * Flutter is the orchestrator: it polls /mdm/devices/commands, calls
 * [execute] for each, and POSTs the result to the ack endpoint. Keeping the
 * dispatch here (not in Dart) means the privileged DevicePolicyManager calls
 * never cross the method channel.
 */
object MdmCommandExecutor {

    private const val TAG = "WorkforceMdm"

    data class Outcome(val ok: Boolean, val detail: String)

    fun isDeviceOwner(context: Context): Boolean =
        DevicePolicyController(context).isDeviceOwner()

    /** Stable per-device identity + descriptors the server enrolls the device with. */
    @Suppress("HardwareIds")
    fun deviceInfo(context: Context): Map<String, Any?> {
        val androidId = Settings.Secure.getString(
            context.contentResolver, Settings.Secure.ANDROID_ID
        )
        val appVersion = try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        } catch (e: Exception) {
            null
        }
        return mapOf(
            "deviceUid" to (androidId ?: "unknown-${Build.FINGERPRINT}"),
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "osVersion" to "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
            "appVersion" to appVersion,
            "isDeviceOwner" to isDeviceOwner(context)
        )
    }

    fun execute(context: Context, command: String): Outcome {
        Log.i(TAG, "Executing MDM command: $command")
        val policy = DevicePolicyController(context)

        // Transparent device-security commands only. No covert monitoring.
        val r = when (command) {
            "block-uninstall" -> policy.setUninstallBlocked(true)
            "allow-uninstall" -> policy.setUninstallBlocked(false)
            "lock-now" -> policy.lockNow()
            "wipe-device" -> policy.wipeDevice()
            else -> DevicePolicyController.Result(false, "unknown command")
        }
        return Outcome(r.ok, r.detail)
    }
}
