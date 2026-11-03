package com.mindware.workforce

import android.app.admin.DeviceAdminReceiver
import android.content.ComponentName
import android.content.Context
import android.util.Log

/**
 * The device-administration component. When the WorkForce app is provisioned
 * as this device's Device Owner (see docs/MDM_PROVISIONING.md), this receiver
 * is the handle the system gives us for the privileged policies in
 * [DevicePolicyController] -- hiding the app, blocking its uninstall, locking,
 * and factory-wipe.
 *
 * On a normal Play Store install nothing here is active; the app runs as an
 * ordinary app and the MDM commands simply report "not Device Owner".
 */
class WorkforceDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        private const val TAG = "WorkforceDeviceAdmin"

        fun componentName(context: Context): ComponentName =
            ComponentName(context.applicationContext, WorkforceDeviceAdminReceiver::class.java)
    }

    override fun onEnabled(context: Context, intent: android.content.Intent) {
        Log.i(TAG, "Device admin enabled.")
    }

    override fun onDisabled(context: Context, intent: android.content.Intent) {
        Log.w(TAG, "Device admin disabled.")
    }
}
