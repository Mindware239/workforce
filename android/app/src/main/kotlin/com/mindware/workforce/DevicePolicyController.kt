package com.mindware.workforce

import android.app.admin.DevicePolicyManager
import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Thin wrapper over [DevicePolicyManager] for the admin-issued MDM commands.
 *
 * Every privileged call first checks [isDeviceOwner]; off a provisioned device
 * these are no-ops that report back "not device owner" rather than throwing, so
 * the same app binary runs fine as an ordinary Play Store install.
 *
 * Note on scope: Android deliberately gives even a Device Owner no API to read
 * call logs or silently capture the screen. Those two MDM features are built on
 * top of this (call-log via a restricted runtime permission on self-distributed
 * builds; screen via MediaProjection with an on-device consent prompt) and live
 * in their own controllers -- this class is only the DevicePolicyManager parts.
 */
class DevicePolicyController(context: Context) {

    private val appContext = context.applicationContext
    private val dpm =
        appContext.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val admin = WorkforceDeviceAdminReceiver.componentName(appContext)

    companion object {
        private const val TAG = "WorkforceDevicePolicy"
    }

    fun isDeviceOwner(): Boolean = dpm.isDeviceOwnerApp(appContext.packageName)

    /** Stops (or re-allows) the user uninstalling the app. */
    fun setUninstallBlocked(blocked: Boolean): Result {
        if (!isDeviceOwner()) return Result.notOwner()
        return try {
            dpm.setUninstallBlocked(admin, appContext.packageName, blocked)
            Result.ok(if (blocked) "uninstall blocked" else "uninstall allowed")
        } catch (e: Exception) {
            Result.error(e)
        }
    }

    fun lockNow(): Result {
        if (!isDeviceOwner()) return Result.notOwner()
        return try {
            dpm.lockNow()
            Result.ok("locked")
        } catch (e: Exception) {
            Result.error(e)
        }
    }

    /** Factory-resets the device. Irreversible; the admin double-confirms server-side. */
    fun wipeDevice(): Result {
        if (!isDeviceOwner()) return Result.notOwner()
        return try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                DevicePolicyManager.WIPE_EUICC
            } else {
                0
            }
            dpm.wipeData(flags)
            Result.ok("wipe requested")
        } catch (e: Exception) {
            Result.error(e)
        }
    }

    data class Result(val ok: Boolean, val detail: String) {
        companion object {
            fun ok(detail: String) = Result(true, detail)
            fun notOwner() = Result(false, "not device owner").also {
                Log.w(TAG, "Privileged command ignored: app is not Device Owner.")
            }
            fun error(e: Exception) = Result(false, "error: ${e.message}").also {
                Log.e(TAG, "Device policy command failed.", e)
            }
        }
    }
}
