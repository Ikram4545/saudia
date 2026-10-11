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
                "syncSettings" -> {
                    try {
                        val runAutoEngine = call.argument<Boolean>("runAutoEngine") ?: true
                        val minPrice = (call.argument<Double>("minPrice") ?: 10.0).toFloat()
                        val maxPrice = (call.argument<Double>("maxPrice") ?: 200.0).toFloat()
                        val maxPickupTime = (call.argument<Double>("maxPickupTime") ?: 15.0).toFloat()
                        val autoReject = call.argument<Boolean>("autoReject") ?: false
                        val blockedLocationsList = call.argument<List<String>>("blockedLocations") ?: emptyList()
                        val avoidWordsList = call.argument<List<String>>("avoidWords") ?: emptyList()

                        val prefs = getSharedPreferences(DrivingCareAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putBoolean("run_auto_engine", runAutoEngine)
                            putFloat("min_price", minPrice)
                            putFloat("max_price", maxPrice)
                            putFloat("max_pickup_time", maxPickupTime)
                            putBoolean("auto_reject", autoReject)
                            putStringSet("blocked_locations", blockedLocationsList.toSet())
                            putStringSet("avoid_words", avoidWordsList.toSet())
                            apply()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SYNC_ERROR", e.message, null)
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
                else -> result.notImplemented()
            }
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
