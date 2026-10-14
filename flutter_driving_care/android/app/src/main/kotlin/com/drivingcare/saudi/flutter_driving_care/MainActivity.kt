package com.drivingcare.saudi.flutter_driving_care

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.drivingcare.saudi/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "isBatteryOptExempt" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    val isExempt = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(isExempt)
                }
                "openBatterySettings" -> {
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                            } catch (e: Exception) {
                                val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                            }
                        } else {
                            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallback)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_SETTING_ERROR", e.message, null)
                    }
                }
                "canDrawOverlays" -> {
                    val canDraw = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(canDraw)
                }
                "openOverlaySettings" -> {
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OVERLAY_SETTING_ERROR", e.message, null)
                    }
                }
                "openAppDetailsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "launchPackage" -> {
                    val pkg = call.argument<String>("package")
                    if (pkg.isNullOrEmpty()) {
                        result.success(false)
                    } else {
                        try {
                            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "isPackageInstalled" -> {
                    val pkg = call.argument<String>("package")
                    if (pkg.isNullOrEmpty()) {
                        result.success(false)
                    } else {
                        try {
                            packageManager.getPackageInfo(pkg, 0)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openPlayStore" -> {
                    val pkg = call.argument<String>("package") ?: "me.jeeny.driver"
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "areNotificationsEnabled" -> {
                    try {
                        val enabled = androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled()
                        result.success(enabled)
                    } catch (e: Exception) {
                        try {
                            val notifManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            val enabled = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                                notifManager?.areNotificationsEnabled() ?: false
                            } else {
                                true
                            }
                            result.success(enabled)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "requestNotificationPermission" -> {
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= 33) {
                            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_ERROR", e.message, null)
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_SETTINGS_ERROR", e.message, null)
                    }
                }
                "getDeviceId" -> {
                    try {
                        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN_DEVICE"
                        result.success(androidId)
                    } catch (e: Exception) {
                        result.success("UNKNOWN_DEVICE")
                    }
                }
                "syncSettings" -> {
                    try {
                        // Every key is written ONLY when the caller actually sent it,
                        // so a partial sync (e.g. just the feature flags) can never
                        // clobber settings it did not mention.
                        val prefs = getSharedPreferences(DrivingCareAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        call.argument<Boolean>("runAutoEngine")?.let { editor.putBoolean("run_auto_engine", it) }
                        call.argument<Double>("minPrice")?.let { editor.putFloat("min_price", it.toFloat()) }
                        call.argument<Double>("maxPrice")?.let { editor.putFloat("max_price", it.toFloat()) }
                        call.argument<Double>("maxPickupTime")?.let { editor.putFloat("max_pickup_time", it.toFloat()) }
                        call.argument<Boolean>("autoReject")?.let { editor.putBoolean("auto_reject", it) }
                        call.argument<List<String>>("blockedLocations")?.let { editor.putStringSet("blocked_locations", it.toSet()) }
                        call.argument<List<String>>("avoidWords")?.let { editor.putStringSet("avoid_words", it.toSet()) }
                        // Feature flags used by the notification listener + floating button
                        call.argument<Boolean>("licenseActive")?.let { editor.putBoolean("license_active", it) }
                        call.argument<Boolean>("showFloatingButton")?.let { editor.putBoolean("show_floating_button", it) }
                        call.argument<Boolean>("autoLaunchOnNotification")?.let { editor.putBoolean("auto_launch_on_notification", it) }
                        editor.apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SYNC_ERROR", e.message, null)
                    }
                }
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "openNotificationListenerSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_LISTENER_SETTINGS_ERROR", e.message, null)
                    }
                }
                "getNativeFlags" -> {
                    try {
                        val prefs = getSharedPreferences(DrivingCareAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
                        val map = HashMap<String, Any>()
                        map["runAutoEngine"] = prefs.getBoolean("run_auto_engine", true)
                        map["showFloatingButton"] = prefs.getBoolean("show_floating_button", true)
                        map["autoLaunchOnNotification"] = prefs.getBoolean("auto_launch_on_notification", true)
                        map["licenseActive"] = prefs.getBoolean("license_active", false)
                        map["lastAutoLaunchPkg"] = prefs.getString("last_auto_launch_pkg", "") ?: ""
                        map["lastAutoLaunchAt"] = prefs.getLong("last_auto_launch_at", 0L)
                        result.success(map)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "openWhatsApp" -> {
                    val phone = call.argument<String>("phone") ?: "03113154649"
                    val message = call.argument<String>("message") ?: "Assalam-o-Alaikum Ikram bhai"
                    try {
                        val cleanPhone = phone.replace("+", "").replace("-", "").replace(" ", "").trim()
                        val formattedPhone = if (cleanPhone.startsWith("0")) "92" + cleanPhone.substring(1) else cleanPhone
                        val url = "https://api.whatsapp.com/send?phone=$formattedPhone&text=${java.net.URLEncoder.encode(message, "UTF-8")}"
                        val intent = Intent(Intent.ACTION_VIEW)
                        intent.data = Uri.parse(url)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WHATSAPP_ERROR", e.message, null)
                    }
                }
                "saveLicenseCache" -> {
                    try {
                        val key = call.argument<String>("key") ?: ""
                        val name = call.argument<String>("name") ?: "Driver"
                        val days = call.argument<Int>("days") ?: 30
                        val boundDeviceId = call.argument<String>("bound_device_id") ?: ""
                        val prefs = getSharedPreferences("DrivingCareLicenseCache", Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putString("key", key)
                            putString("name", name)
                            putInt("days", days)
                            putLong("savedAt", System.currentTimeMillis())
                            if (boundDeviceId.isNotEmpty()) {
                                putString("bound_device_id", boundDeviceId)
                            }
                            apply()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CACHE_ERROR", e.message, null)
                    }
                }
                "loadLicenseCache" -> {
                    try {
                        val prefs = getSharedPreferences("DrivingCareLicenseCache", Context.MODE_PRIVATE)
                        val key = prefs.getString("key", null)
                        if (key != null && key.isNotEmpty()) {
                            val map = HashMap<String, Any>()
                            map["key"] = key
                            map["name"] = prefs.getString("name", "Driver") ?: "Driver"
                            map["days"] = prefs.getInt("days", 30)
                            map["savedAt"] = prefs.getLong("savedAt", 0L)
                            map["bound_device_id"] = prefs.getString("bound_device_id", "") ?: ""
                            result.success(map)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("CACHE_ERROR", e.message, null)
                    }
                }
                "clearLicenseCache" -> {
                    try {
                        val prefs = getSharedPreferences("DrivingCareLicenseCache", Context.MODE_PRIVATE)
                        prefs.edit().clear().apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CACHE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false

        return enabledListeners.split(":").any { component ->
            component.contains(packageName, ignoreCase = true) &&
                component.contains("DrivingCareNotificationListener", ignoreCase = true)
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "$packageName/${DrivingCareAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedService, ignoreCase = true) ||
                componentName.contains("DrivingCareAccessibilityService", ignoreCase = true)
            ) {
                return true
            }
        }
        return false
    }
}
