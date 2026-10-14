package com.drivingcare.saudi.flutter_driving_care

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.TextView
import android.widget.Toast

class DrivingCareAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "DrivingCareEngine"
        const val PREFS_NAME = "DrivingCarePrefs"
        const val CHANNEL_ID = "driving_care_autopilot_channel"
        const val NOTIF_ID = 1001

        var isServiceRunning = false
        var instance: DrivingCareAccessibilityService? = null
    }

    private lateinit var prefs: SharedPreferences
    private var lastActionTime: Long = 0

    // Floating button (HUD) state
    private var windowManager: WindowManager? = null
    private var hudView: TextView? = null
    private var hudParams: WindowManager.LayoutParams? = null
    private var hudPrefsListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    fun showStatusNotification(statusText: String) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    CHANNEL_ID,
                    "Driving Care Saudi Autopilot",
                    android.app.NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Driving Care Saudi Ride-Hailing Bot Status"
                    setShowBadge(false)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = if (launchIntent != null) {
                android.app.PendingIntent.getActivity(
                    this,
                    0,
                    launchIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.app.PendingIntent.FLAG_IMMUTABLE else 0
                )
            } else null

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(this)
            }

            val notification = builder
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Driving Care Saudi 🟢")
                .setContentText(statusText)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .build()

            notificationManager.notify(NOTIF_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Notification error: ${e.message}")
        }
    }

    // Common Ride-Hailing Driver & Captain App Package Names in Saudi Arabia
    private val targetPackageSubstrings = listOf(
        "jeeny",
        "captain",
        "driver",
        "easytaxi",
        "uber",
        "ubercab",
        "bolt",
        "mtakso",
        "careem",
        "tawseel",
        "kaiian",
        "ego",
        "shgardi"
    )

    // Accept keywords in Arabic and English (covering Jeeny, Uber, Bolt, Careem)
    private val acceptKeywords = listOf(
        "قبول",
        "قبول الطلب",
        "قبول المشوار",
        "تأكيد",
        "تأكيد الطلب",
        "استلام",
        "طلب جديد",
        "اضغط للقبول",
        "accept",
        "tap to accept",
        "confirm",
        "take order",
        "take ride",
        "match",
        "accept order"
    )

    // Swipe keywords for slider buttons
    private val swipeKeywords = listOf(
        "اسحب للقبول",
        "اسحب",
        "swipe to accept",
        "slide to accept"
    )

    // Reject keywords in Arabic and English
    private val rejectKeywords = listOf(
        "رفض",
        "تجاهل",
        "إلغاء",
        "reject",
        "decline",
        "dismiss",
        "skip"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        instance = this
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        Log.d(TAG, "Driving Care Native Accessibility Auto-Clicker Connected & Active!")
        showStatusNotification("Autopilot Active — Monitoring Jeeny & Ride Requests")
        registerHudPrefsListener()
        refreshHud()
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        isServiceRunning = false
        instance = null
        teardownHud()
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(NOTIF_ID)
        } catch (e: Exception) {}
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        isServiceRunning = false
        instance = null
        teardownHud()
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(NOTIF_ID)
        } catch (e: Exception) {}
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: ""

        // Check if event is from our target driver/captain apps or system overlays
        val isTarget = targetPackageSubstrings.any { packageName.contains(it, ignoreCase = true) }
        
        // Always read latest prefs
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEngineOn = prefs.getBoolean("run_auto_engine", true)
        if (!isEngineOn) return

        // Fast Debounce: 600ms to allow ultra-fast reaction without duplicate spam
        val now = System.currentTimeMillis()
        if (now - lastActionTime < 600) return

        try {
            val rootNode = rootInActiveWindow ?: return
            
            // If package doesn't strictly match, check if screen has ride dispatch keywords
            if (!isTarget) {
                val hasRideKeywords = hasRideOfferKeywords(rootNode)
                if (!hasRideKeywords) return
            }

            processDriverScreen(rootNode)
        } catch (e: Exception) {
            Log.e(TAG, "Error in processDriverScreen", e)
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "Driving Care Service Interrupted")
    }

    /**
     * Checks if the window contains ride offer indicators (in case package is a system overlay)
     */
    private fun hasRideOfferKeywords(rootNode: AccessibilityNodeInfo): Boolean {
        val texts = mutableListOf<String>()
        collectAllTexts(rootNode, texts)
        val full = texts.joinToString(" ").lowercase()
        return acceptKeywords.any { full.contains(it.lowercase()) } ||
                full.contains("sar") || full.contains("ر.س") || full.contains("ريال")
    }

    /**
     * Scans the driver app window, checks price, pickup time, and blocked locations,
     * and triggers auto-accept or auto-reject.
     */
    private fun processDriverScreen(rootNode: AccessibilityNodeInfo) {
        val texts = mutableListOf<String>()
        collectAllTexts(rootNode, texts)
        if (texts.isEmpty()) return

        val rawFullScreenText = texts.joinToString(" ")
        val normalizedText = normalizeArabicDigits(rawFullScreenText).lowercase()

        // Read configured rules (with generous defaults)
        val minPrice = prefs.getFloat("min_price", 10f)
        val maxPrice = prefs.getFloat("max_price", 200f)
        val autoReject = prefs.getBoolean("auto_reject", false)
        val blockedLocations = prefs.getStringSet("blocked_locations", emptySet()) ?: emptySet()
        val avoidWords = prefs.getStringSet("avoid_words", emptySet()) ?: emptySet()

        // 1. Check if screen mentions any Blocked Locations or Avoid Words
        var isLocationBlocked = false
        for (blocked in blockedLocations) {
            if (blocked.isNotBlank() && normalizedText.contains(blocked.lowercase())) {
                isLocationBlocked = true
                Log.d(TAG, "Blocked Location Detected: $blocked")
                break
            }
        }
        for (avoid in avoidWords) {
            if (avoid.isNotBlank() && normalizedText.contains(avoid.lowercase())) {
                isLocationBlocked = true
                Log.d(TAG, "Avoid Word Detected: $avoid")
                break
            }
        }

        // 2. Parse price from text (Supports Arabic numerals & SAR currency)
        val extractedPrice = extractPrice(normalizedText)
        Log.d(TAG, "Extracted Price: $extractedPrice SAR (Range: $minPrice - $maxPrice)")

        // 3. Decision Logic:
        val priceEligible = if (extractedPrice != null) {
            extractedPrice in minPrice..maxPrice
        } else {
            // If price not found or unparseable, default to TRUE so driver doesn't miss the ride
            true
        }

        if (isLocationBlocked) {
            if (autoReject) {
                val rejectBtn = findButtonByKeywords(rootNode, rejectKeywords)
                if (rejectBtn != null) {
                    performClick(rejectBtn, "Auto-Rejected (Blocked Location)")
                    lastActionTime = System.currentTimeMillis()
                }
            }
            return
        }

        if (priceEligible) {
            // 4. Check for Swipe Sliders first
            val swipeBtn = findButtonByKeywords(rootNode, swipeKeywords)
            if (swipeBtn != null) {
                performSwipeGesture(swipeBtn)
                lastActionTime = System.currentTimeMillis()
                Log.d(TAG, "Auto-Accepted ride via SWIPE gesture!")
                return
            }

            // 5. Look for Accept Button and click it!
            val acceptBtn = findButtonByKeywords(rootNode, acceptKeywords)
            if (acceptBtn != null) {
                performClick(acceptBtn, "Auto-Accepted Ride! 🚗⚡")
                lastActionTime = System.currentTimeMillis()
                Log.d(TAG, "Auto-Accepted ride successfully!")
            }
        } else if (autoReject && extractedPrice != null && extractedPrice < minPrice) {
            // Price is below minimum requirement -> Auto Reject
            val rejectBtn = findButtonByKeywords(rootNode, rejectKeywords)
            if (rejectBtn != null) {
                performClick(rejectBtn, "Auto-Rejected ($extractedPrice SAR < $minPrice SAR)")
                lastActionTime = System.currentTimeMillis()
            }
        }
    }

    private fun collectAllTexts(node: AccessibilityNodeInfo?, outList: MutableList<String>) {
        if (node == null) return
        node.text?.let { if (it.isNotBlank()) outList.add(it.toString()) }
        node.contentDescription?.let { if (it.isNotBlank()) outList.add(it.toString()) }

        for (i in 0 until node.childCount) {
            collectAllTexts(node.getChild(i), outList)
        }
    }

    /**
     * Converts Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) to standard ASCII digits (0-9)
     */
    private fun normalizeArabicDigits(input: String): String {
        val arabicDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        var result = input
        for (i in arabicDigits.indices) {
            result = result.replace(arabicDigits[i], (i + '0'.code).toChar())
        }
        return result
    }

    /**
     * Extracts SAR fare safely while avoiding ratings (4.8 ★) and distances (3 km)
     */
    private fun extractPrice(text: String): Float? {
        // Pattern 1: Number followed by currency (e.g., "25.5 SAR", "30 ر.س", "40 ريال")
        val regex1 = Regex("""(\d+(?:\.\d+)?)\s*(?:sar|sr|ر\.س|ريال)""", RegexOption.IGNORE_CASE)
        val match1 = regex1.find(text)
        if (match1 != null) {
            val p = match1.groupValues[1].toFloatOrNull()
            if (p != null && p > 0) return p
        }

        // Pattern 2: Currency followed by number (e.g., "SAR 25", "ر.س 30", "ريال 40")
        val regex2 = Regex("""(?:sar|sr|ر\.س|ريال)\s*(\d+(?:\.\d+)?)""", RegexOption.IGNORE_CASE)
        val match2 = regex2.find(text)
        if (match2 != null) {
            val p = match2.groupValues[1].toFloatOrNull()
            if (p != null && p > 0) return p
        }

        return null
    }

    private fun findButtonByKeywords(
        node: AccessibilityNodeInfo?,
        keywords: List<String>
    ): AccessibilityNodeInfo? {
        if (node == null) return null

        val nodeText = (node.text?.toString() ?: "").lowercase()
        val contentDesc = (node.contentDescription?.toString() ?: "").lowercase()
        val viewId = (node.viewIdResourceName ?: "").lowercase()

        // 1. Check text & content description
        for (kw in keywords) {
            val k = kw.lowercase()
            if (nodeText.contains(k) || contentDesc.contains(k)) {
                var target: AccessibilityNodeInfo? = node
                while (target != null && !target.isClickable) {
                    val p = target.parent ?: break
                    target = p
                }
                return target ?: node
            }
        }

        // 2. Check Android View ID Resource Name (e.g., btn_accept, action_accept, accept_button)
        if (viewId.contains("accept") || viewId.contains("confirm") || viewId.contains("take_order") || viewId.contains("action_order")) {
            var target: AccessibilityNodeInfo? = node
            while (target != null && !target.isClickable) {
                val p = target.parent ?: break
                target = p
            }
            return target ?: node
        }

        // 3. Recurse children
        for (i in 0 until node.childCount) {
            val found = findButtonByKeywords(node.getChild(i), keywords)
            if (found != null) return found
        }
        return null
    }

    /**
     * Executes BOTH standard Accessibility Click AND physical touchscreen tap gesture
     * to guarantee click registration across Jetpack Compose, Flutter, React Native, and native Views.
     */
    private fun performClick(node: AccessibilityNodeInfo, toastMsg: String = "Driving Care: Auto-Accepted! 🚗⚡") {
        // 1. Accessibility Action Click
        var actionClicked = false
        if (node.isClickable) {
            actionClicked = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        } else {
            var parent = node.parent
            while (parent != null) {
                if (parent.isClickable) {
                    actionClicked = parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    if (actionClicked) break
                }
                parent = parent.parent
            }
        }

        // 2. Physical Screen Tap via Gesture Description (Solid 120ms tap at exact coordinates)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() > 0 && rect.height() > 0) {
                val clickPath = Path().apply {
                    moveTo(rect.centerX().toFloat(), rect.centerY().toFloat())
                }
                val gesture = GestureDescription.Builder()
                    .addStroke(GestureDescription.StrokeDescription(clickPath, 0, 120))
                    .build()
                dispatchGesture(gesture, null, null)
                Log.d(TAG, "Dispatched physical screen tap at (${rect.centerX()}, ${rect.centerY()}) [actionClicked=$actionClicked]")
            }
        }

        // Show Instant Toast on screen so driver sees the bot working!
        try {
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(applicationContext, toastMsg, Toast.LENGTH_SHORT).show()
            }
        } catch (_: Exception) {}
    }

    /**
     * Performs a horizontal swipe gesture across the button (for slide-to-accept widgets)
     */
    private fun performSwipeGesture(node: AccessibilityNodeInfo) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() > 0 && rect.height() > 0) {
                val swipePath = Path().apply {
                    moveTo(rect.left.toFloat() + 30f, rect.centerY().toFloat())
                    lineTo(rect.right.toFloat() - 30f, rect.centerY().toFloat())
                }
                val gesture = GestureDescription.Builder()
                    .addStroke(GestureDescription.StrokeDescription(swipePath, 0, 250))
                    .build()
                dispatchGesture(gesture, null, null)
                Log.d(TAG, "Dispatched swipe-to-accept gesture across (${rect.left} to ${rect.right})")

                try {
                    Handler(Looper.getMainLooper()).post {
                        Toast.makeText(applicationContext, "Driving Care: Accepted via Swipe! 🚗⚡", Toast.LENGTH_SHORT).show()
                    }
                } catch (_: Exception) {}
            }
        }
    }

    // ---------------------------------------------------------------------
    // Floating button (HUD)
    //
    // A small round "DC" button that floats above every app (including Jeeny).
    // GREEN = engine ON, RED = engine OFF. A tap toggles the engine by flipping
    // the same "run_auto_engine" preference the Flutter dashboard uses, and the
    // button can be dragged anywhere on screen (position is remembered).
    // It lives inside this AccessibilityService because the engine cannot work
    // without the service anyway; it only appears when the driver has granted
    // the Display-Over-Other-Apps (overlay) permission and the in-app
    // "Floating button" switch is ON.
    // ---------------------------------------------------------------------

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun registerHudPrefsListener() {
        if (hudPrefsListener != null) return
        hudPrefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == "run_auto_engine" || key == "show_floating_button") {
                Handler(Looper.getMainLooper()).post { refreshHud() }
            }
        }
        try {
            prefs.registerOnSharedPreferenceChangeListener(hudPrefsListener)
        } catch (_: Exception) {}
    }

    private fun teardownHud() {
        hudPrefsListener?.let {
            try {
                prefs.unregisterOnSharedPreferenceChangeListener(it)
            } catch (_: Exception) {}
        }
        hudPrefsListener = null
        hideHud()
    }

    private fun refreshHud() {
        val show = prefs.getBoolean("show_floating_button", true)
        if (show) {
            if (hudView == null) showHud()
            updateHudColor()
        } else {
            hideHud()
        }
    }

    private fun hudBackground(engineOn: Boolean): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (engineOn) 0xFF10B981.toInt() else 0xFFEF4444.toInt())
            setStroke(dp(2), 0xFFFFFFFF.toInt())
        }
    }

    private fun updateHudColor() {
        hudView?.background = hudBackground(prefs.getBoolean("run_auto_engine", true))
    }

    private fun showHud() {
        try {
            if (hudView != null) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                Log.d(TAG, "Floating button skipped: overlay permission not granted")
                return
            }
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val size = dp(56)
            val button = TextView(this).apply {
                text = "DC"
                textSize = 15f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                background = hudBackground(prefs.getBoolean("run_auto_engine", true))
            }
            val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val params = WindowManager.LayoutParams(
                size,
                size,
                windowType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = prefs.getInt("hud_x", resources.displayMetrics.widthPixels - size - dp(12))
                y = prefs.getInt("hud_y", (resources.displayMetrics.heightPixels * 0.38).toInt())
            }
            button.setOnTouchListener(HudTouchListener(params))
            windowManager?.addView(button, params)
            hudView = button
            hudParams = params
            Log.d(TAG, "Floating button shown")
        } catch (e: Exception) {
            Log.e(TAG, "showHud failed: ${e.message}")
        }
    }

    private fun hideHud() {
        try {
            hudView?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {}
        hudView = null
        hudParams = null
    }

    private fun toggleEngineFromHud() {
        val newState = !prefs.getBoolean("run_auto_engine", true)
        prefs.edit().putBoolean("run_auto_engine", newState).apply()
        updateHudColor()
        showStatusNotification(
            if (newState) {
                "Autopilot Active — Monitoring Jeeny & Ride Requests"
            } else {
                "Autopilot Paused — tap the floating button to resume"
            }
        )
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(
                applicationContext,
                if (newState) "Driving Care Engine ON 🟢" else "Driving Care Engine OFF 🔴",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private inner class HudTouchListener(
        private val params: WindowManager.LayoutParams
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchRawX = 0f
        private var touchRawY = 0f
        private var moved = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchRawX = event.rawX
                    touchRawY = event.rawY
                    moved = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchRawX).toInt()
                    val dy = (event.rawY - touchRawY).toInt()
                    if (Math.abs(dx) > dp(6) || Math.abs(dy) > dp(6)) moved = true
                    params.x = startX + dx
                    params.y = startY + dy
                    try {
                        windowManager?.updateViewLayout(view, params)
                    } catch (_: Exception) {}
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        toggleEngineFromHud()
                    } else {
                        prefs.edit()
                            .putInt("hud_x", params.x)
                            .putInt("hud_y", params.y)
                            .apply()
                    }
                    return true
                }
            }
            return false
        }
    }
}
