package com.drivingcare.saudi.flutter_driving_care

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Driving Care — Order Notification Listener.
 *
 * Purpose: when a ride-hailing driver app (Jeeny / Uber / Bolt / Careem) posts an
 * order notification while that app is in the background or closed, this listener
 * brings the app straight to the foreground so the Accessibility engine can see
 * the order screen and auto-accept it. Without this listener the engine can only
 * react when the driver app is already on screen.
 *
 * Safety gates (all read from the shared "DrivingCarePrefs" file that the Flutter
 * side keeps updated through the syncSettings channel call):
 *  - license_active must be true (no license / locked = never launch anything)
 *  - run_auto_engine must be true (driver paused the engine = respect it)
 *  - auto_launch_on_notification must be true (driver can switch this off)
 *
 * Launch strategy: first fire the notification's own contentIntent (Android
 * treats this like the driver tapping the notification, so it is not blocked by
 * background-activity-launch limits and it opens the exact order screen). If the
 * notification has no usable intent, fall back to the app's launch intent.
 */
class DrivingCareNotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "DrivingCareNotif"
        private const val DEBOUNCE_MS = 10_000L

        @Volatile
        private var lastLaunchAt: Long = 0L

        @Volatile
        private var lastLaunchPkg: String = ""
    }

    // Exact driver-app packages (mirrors the Dart jeenyPackages/uberPackages/boltPackages lists)
    private val targetPackages = setOf(
        "me.jeeny.driver",
        "com.jeeny.driver",
        "me.jeeny.captain",
        "com.easytaxi.driver",
        "com.ubercab.driver",
        "ee.mtakso.driver"
    )

    // Substring fallbacks for regional variants of the same driver apps
    private val targetSubstrings = listOf("jeeny", "easytaxi", "careem")

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Driving Care notification listener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        // Ask the system to reconnect us if we get disconnected
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(android.content.ComponentName(this, DrivingCareNotificationListener::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "requestRebind failed: ${e.message}")
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        try {
            val pkg = sbn.packageName ?: return
            if (pkg == packageName) return
            if (!isTargetPackage(pkg)) return

            val notification = sbn.notification ?: return

            // Skip persistent "you are online" style notifications and group summaries:
            // only real, tappable order alerts should pull the app forward.
            val flags = notification.flags
            if (flags and Notification.FLAG_ONGOING_EVENT != 0) return
            if (flags and Notification.FLAG_GROUP_SUMMARY != 0) return

            val prefs = getSharedPreferences(
                DrivingCareAccessibilityService.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val licenseActive = prefs.getBoolean("license_active", false)
            val engineOn = prefs.getBoolean("run_auto_engine", true)
            val autoLaunch = prefs.getBoolean("auto_launch_on_notification", true)
            if (!licenseActive || !engineOn || !autoLaunch) {
                Log.d(
                    TAG,
                    "Order notification from $pkg ignored (license=$licenseActive engine=$engineOn autoLaunch=$autoLaunch)"
                )
                return
            }

            // Debounce: never yank the same app forward twice within a few seconds
            val now = System.currentTimeMillis()
            if (pkg == lastLaunchPkg && now - lastLaunchAt < DEBOUNCE_MS) return

            val broughtForward = bringAppForward(pkg, notification)
            if (broughtForward) {
                lastLaunchAt = now
                lastLaunchPkg = pkg
                prefs.edit()
                    .putString("last_auto_launch_pkg", pkg)
                    .putLong("last_auto_launch_at", now)
                    .apply()
                Log.d(TAG, "Brought $pkg forward for an incoming order notification")
            }
        } catch (e: Exception) {
            Log.e(TAG, "onNotificationPosted error: ${e.message}")
        }
    }

    private fun isTargetPackage(pkg: String): Boolean {
        if (targetPackages.contains(pkg)) return true
        val lower = pkg.lowercase()
        return targetSubstrings.any { lower.contains(it) }
    }

    private fun bringAppForward(pkg: String, notification: Notification): Boolean {
        // Route 1 (preferred): fire the notification's own PendingIntent.
        // This is treated by Android like the driver tapping the notification,
        // so background-launch restrictions do not block it, and it opens the
        // exact order screen inside the driver app.
        val contentIntent = notification.contentIntent
        if (contentIntent != null) {
            try {
                contentIntent.send()
                return true
            } catch (e: PendingIntent.CanceledException) {
                Log.w(TAG, "Notification intent cancelled for $pkg, falling back to launch intent")
            } catch (e: Exception) {
                Log.w(TAG, "Notification intent failed for $pkg: ${e.message}")
            }
        }

        // Route 2 (fallback): plain launch intent for the app.
        return try {
            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
            if (launchIntent != null) {
                launchIntent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                startActivity(launchIntent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "Launch intent failed for $pkg: ${e.message}")
            false
        }
    }
}
