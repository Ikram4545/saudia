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

    // Strict Target Driver App Package Names in Saudi Arabia (Strictly Jeeny Driver)
    private val targetPackageSubstrings = listOf(
        "me.com.easytaxista",
        "easytaxista",
        "jeeny",
        "easytaxi"
    )

    // Accept keywords in Arabic and English (covering Jeeny, Uber, Bolt, Careem)
    private val acceptKeywords = listOf(
        "قبول",
        "قبول الطلب",
        "قبول المشوار",
        "قبول العرض",
        "تأكيد",
        "تأكيد الطلب",
        "تأكيد المشوار",
        "استلام",
        "استلام الطلب",
        "طلب جديد",
        "اضغط للقبول",
        "موافق",
        "موافقة",
        "ارسال عرض",
        "تقديم عرض",
        "عرض سعر",
        "ابدأ",
        "تنفيذ",
        "جاهز",
        "accept",
        "tap to accept",
        "confirm",
        "take order",
        "take ride",
        "match",
        "accept order",
        "accept offer",
        "agree",
        "send offer",
        "submit offer"
    )

    // Swipe keywords for slider buttons (explicit phrases only so normal buttons are never swiped)
    private val explicitSwipeKeywords = listOf(
        "اسحب للقبول",
        "اسحب للتأكيد",
        "اسحب لبدء",
        "مرر للقبول",
        "مرر للتأكيد",
        "swipe to accept",
        "slide to accept"
    )

    // Words indicating driver wallet/balance/earnings — MUST NOT be treated as order price!
    private val walletKeywords = listOf(
        "رصيد",
        "المحفظة",
        "محفظة",
        "أرباح",
        "ارباح",
        "حساب",
        "شحن",
        "balance",
        "wallet",
        "earnings",
        "top up",
        "recharge",
        "today"
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

        // Always read latest prefs
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEngineOn = prefs.getBoolean("run_auto_engine", true)
        if (!isEngineOn) return

        // STRICT APP LOCK: Strictly Jeeny Driver only (or Uber/Bolt if driver explicitly enabled them)
        // Strictly ignore third-party apps like Sama, Jahez, Hungerstation, WhatsApp, etc.
        val isJeeny = packageName.contains("easytaxista", ignoreCase = true) ||
                      packageName.contains("jeeny", ignoreCase = true) ||
                      packageName.contains("easytaxi", ignoreCase = true)
        val allowUber = prefs.getBoolean("uber_enabled", false) && packageName.contains("ubercab", ignoreCase = true)
        val allowBolt = prefs.getBoolean("bolt_enabled", false) && (packageName.contains("bolt", ignoreCase = true) || packageName.contains("mtakso", ignoreCase = true))

        if (!(isJeeny || allowUber || allowBolt)) {
            return
        }

        // Fast Debounce: 250ms to allow ultra-fast reaction without duplicate spam
        val now = System.currentTimeMillis()
        if (now - lastActionTime < 250) return

        try {
            // Check event.source first (critical for bottom sheets and popup dialogs), fallback to rootInActiveWindow
            val rootNode = event.source ?: rootInActiveWindow ?: return

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
        return isRealRideOffer(texts) ||
                full.contains("you'll earn") || full.contains("accept offer") ||
                full.contains("قبول العرض") || full.contains("طلب جديد")
    }

    /**
     * Strictly verifies if the screen contains an ACTIVE ride offer bottom-sheet/card.
     * Prevents false triggers on map screen, wallet balances, or "You're Online".
     */
    private fun isRealRideOffer(texts: List<String>): Boolean {
        val full = texts.joinToString(" ").lowercase()

        // 1. Must contain an accept trigger phrase
        val hasAcceptWord = acceptKeywords.any { full.contains(it.lowercase()) }
        if (!hasAcceptWord) return false

        // 2. Must contain ride offer context (cannot just be map + balance)
        val hasOfferContext = full.contains("you'll earn") || full.contains("you will earn") ||
                full.contains("away") || full.contains("bonus") || full.contains("net earning") ||
                full.contains("priority") || full.contains("city ride") || full.contains("eco") ||
                full.contains("pickup") || full.contains("dropoff") || full.contains("مشوار") ||
                full.contains("طلب جديد") || full.contains("عرض جديد") || full.contains("دقيقة") ||
                full.contains("كم") || full.contains("استلام")

        return hasOfferContext
    }

    /**
     * Splits complex location names (like "Airport (مطار)") into separate Arabic & English search tokens
     * so that either language matches the driver screen accurately.
     */
    private fun extractLocationKeywords(rawLocation: String): List<String> {
        val keywords = mutableListOf<String>()
        val parts = rawLocation.split(Regex("""[()/,\-]"""))
        for (part in parts) {
            val clean = part.trim().lowercase()
            if (clean.length >= 3) {
                keywords.add(clean)
            }
        }
        val lower = rawLocation.lowercase()
        if (lower.contains("airport") || lower.contains("مطار")) {
            keywords.addAll(listOf("airport", "مطار", "المطار", "king khalid"))
        }
        if (lower.contains("bat'ha") || lower.contains("batha") || lower.contains("بطحاء")) {
            keywords.addAll(listOf("batha", "bat'ha", "al batha", "البطحاء", "بطحاء"))
        }
        if (lower.contains("shamisi") || lower.contains("شميسي")) {
            keywords.addAll(listOf("shamisi", "al-shamisi", "al shamisi", "الشميسي", "شميسي"))
        }
        if (lower.contains("manfuhah") || lower.contains("منفوحة") || lower.contains("manfuha")) {
            keywords.addAll(listOf("manfuhah", "manfuha", "منفوحة", "منفوحه"))
        }
        if (lower.contains("railway") || lower.contains("قطار")) {
            keywords.addAll(listOf("railway", "train", "قطار", "محطة القطار", "محطة قطار", "sar station"))
        }
        if (lower.contains("safarat") || lower.contains("سفارات")) {
            keywords.addAll(listOf("safarat", "al safarat", "السفارات", "حي السفارات", "diplomatic"))
        }
        if (lower.contains("kafd") || lower.contains("المالي")) {
            keywords.addAll(listOf("kafd", "كافد", "المالي", "مركز الملك عبدالله المالي"))
        }
        return keywords.distinct()
    }

    /**
     * Scans the driver app window, checks price, pickup time, and blocked locations,
     * and triggers auto-accept or auto-reject.
     */
    private fun processDriverScreen(rootNode: AccessibilityNodeInfo) {
        val texts = mutableListOf<String>()
        collectAllTexts(rootNode, texts)
        if (texts.isEmpty()) return

        // 0. GUARD: Only proceed if this screen is a legitimate ride offer card!
        if (!isRealRideOffer(texts)) {
            return
        }

        val rawFullScreenText = texts.joinToString(" ")
        val normalizedText = normalizeArabicDigits(rawFullScreenText).lowercase()

        // Read configured rules (with generous defaults)
        val minPrice = prefs.getFloat("min_price", 10f)
        val maxPrice = prefs.getFloat("max_price", 200f)
        val autoReject = prefs.getBoolean("auto_reject", false)
        val blockedLocations = prefs.getStringSet("blocked_locations", emptySet()) ?: emptySet()
        val avoidWords = prefs.getStringSet("avoid_words", emptySet()) ?: emptySet()

        // 1. Check if screen mentions any Blocked Locations or Avoid Words (Split Arabic & English tokens)
        var isLocationBlocked = false
        var matchedBlockedKeyword = ""
        for (blocked in blockedLocations) {
            val keywords = extractLocationKeywords(blocked)
            for (kw in keywords) {
                if (kw.isNotBlank() && normalizedText.contains(kw)) {
                    isLocationBlocked = true
                    matchedBlockedKeyword = kw
                    Log.d(TAG, "Blocked Location Detected: '$kw' from rule '$blocked'")
                    break
                }
            }
            if (isLocationBlocked) break
        }
        if (!isLocationBlocked) {
            for (avoid in avoidWords) {
                val clean = avoid.trim().lowercase()
                if (clean.isNotBlank() && normalizedText.contains(clean)) {
                    isLocationBlocked = true
                    matchedBlockedKeyword = clean
                    Log.d(TAG, "Avoid Word Detected: '$clean'")
                    break
                }
            }
        }

        if (isLocationBlocked) {
            Log.d(TAG, "Offer SKIPPED: Blocked location matched '$matchedBlockedKeyword'")
            if (autoReject) {
                val rejectBtn = findNodeByKeywords(rootNode, rejectKeywords)
                if (rejectBtn != null) {
                    performClick(rejectBtn, "Auto-Rejected ($matchedBlockedKeyword)")
                    lastActionTime = System.currentTimeMillis()
                }
            }
            // CRUCIAL: Immediately stop here! Never accept blocked locations!
            return
        }

        // 2. Parse price accurately (Jeeny "You'll earn" or SAR currency)
        val extractedPrice = extractOrderPrice(texts)
        Log.d(TAG, "Extracted Order Price: $extractedPrice SAR (Configured Range: $minPrice - $maxPrice SAR)")

        // 3. STRICT Price Decision Logic:
        // Rule: 10 se neeche na pakre (4, 5, 7, 8, 9 SAR -> SKIP/REJECT!)
        // 10 ya us se zyada (10, 11, 12, 13, 50, 100, 150 SAR) -> ACCEPT!
        if (extractedPrice != null) {
            if (extractedPrice < minPrice) {
                Log.d(TAG, "Order price ($extractedPrice SAR) is BELOW minimum limit ($minPrice SAR). SKIPPING.")
                if (autoReject) {
                    val rejectBtn = findNodeByKeywords(rootNode, rejectKeywords)
                    if (rejectBtn != null) {
                        performClick(rejectBtn, "Auto-Rejected ($extractedPrice SAR < $minPrice SAR)")
                        lastActionTime = System.currentTimeMillis()
                    }
                }
                // CRUCIAL: STOP HERE! DO NOT ACCEPT LOW FARES!
                return
            }
            if (extractedPrice > maxPrice) {
                Log.d(TAG, "Order price ($extractedPrice SAR) is ABOVE maximum limit ($maxPrice SAR). SKIPPING.")
                return
            }
        } else {
            // Price could not be explicitly parsed. Check if ANY number on screen is below minPrice!
            val hasLowCandidate = texts.any { t ->
                val norm = normalizeArabicDigits(t).lowercase()
                if (!norm.contains("km") && !norm.contains("كم") && !norm.contains("min") && !norm.contains("دقيقة") && !norm.contains("★")) {
                    val m = Regex("""\b(\d+(?:\.\d+)?)\b""").find(norm)
                    val num = m?.groupValues?.get(1)?.toFloatOrNull()
                    num != null && num in 1.0f..(minPrice - 0.01f)
                } else false
            }
            if (hasLowCandidate) {
                Log.d(TAG, "Screen contains small price amount below $minPrice SAR. SKIPPING for safety.")
                return
            }
        }

        // 4. Check for Swipe Sliders (ONLY if explicit swipe text present)
        val swipeBtn = findSwipeButton(rootNode)
        if (swipeBtn != null) {
            performSwipeGesture(swipeBtn)
            lastActionTime = System.currentTimeMillis()
            Log.d(TAG, "Auto-Accepted ride via SWIPE gesture!")
            return
        }

        // 5. Look for Accept Button ("Accept Offer" / "قبول" / View IDs) with STRICT bounds
        val acceptBtn = findAcceptButton(rootNode)
        if (acceptBtn != null) {
            performClick(acceptBtn, "Auto-Accepted Ride! 🚗⚡")
            lastActionTime = System.currentTimeMillis()
            Log.d(TAG, "Auto-Accepted ride successfully!")
        } else {
            Log.w(TAG, "Offer detected but accept button container not found")
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
        // Normalize Arabic decimal separators (٫, ،) and commas between digits to standard dot (.)
        result = result.replace('٫', '.')
        result = result.replace('،', '.')
        result = Regex("""(\d+),(\d+)""").replace(result, "$1.$2")
        return result
    }

    /**
     * Extracts ride offer fare accurately:
     * 1. Jeeny English layout ("You'll earn" followed by fare number)
     * 2. Arabic layout ("ستكسب" / "أرباحك" / "سعر")
     * 3. General ride fare (SAR / ر.س / ﷼)
     * Ignores driver's personal wallet/balance lines.
     */
    private fun extractOrderPrice(texts: List<String>): Float? {
        val candidates = mutableListOf<Float>()

        val earningMarkers = listOf(
            "you'll earn", "you will earn", "earn", "earnings",
            "ستكسب", "أرباحك", "ارباحك", "ستربح", "أرباح", "ارباح",
            "أجرة المشوار", "اجرة المشوار", "أجرة الرحلة", "اجرة الرحلة", "الأجرة", "الاجرة",
            "قيمة المشوار", "قيمة الرحلة", "قيمة الطلب", "سعر المشوار", "سعر الرحلة", "سعر الطلب",
            "صافي الأرباح", "صافي الارباح", "صافي الربح"
        )

        val currencyMarkers = listOf(
            "sar", "sr", "ر.س", "رس", "ريال", "﷼", "ر. س"
        )

        // Pass 1: Scan for explicit Earning markers and their numbers
        var markerSeen = false
        for (raw in texts) {
            val normalized = normalizeArabicDigits(raw).lowercase()
            if (walletKeywords.any { normalized.contains(it) }) continue

            val hasMarker = earningMarkers.any { normalized.contains(it) }
            if (hasMarker) {
                markerSeen = true
                val nums = Regex("""\b(\d+(?:\.\d+)?)\b""").findAll(normalized)
                for (n in nums) {
                    val v = n.groupValues[1].toFloatOrNull()
                    if (v != null && v > 0f) {
                        candidates.add(v)
                    }
                }
                continue
            }

            if (markerSeen) {
                if (normalized.contains("bonus") || normalized.contains("vat") || normalized.contains("ضريبة") || normalized.contains("fees")) {
                    continue
                }
                val nums = Regex("""\b(\d+(?:\.\d+)?)\b""").findAll(normalized)
                for (n in nums) {
                    val v = n.groupValues[1].toFloatOrNull()
                    if (v != null && v > 0f && v != 4.18f) {
                        candidates.add(v)
                        markerSeen = false
                        break
                    }
                }
            }
        }

        // Pass 2: Look for currency markers (e.g. "4.5 SAR", "7.00 ر.س", "SAR 15", "ريال 50")
        for (raw in texts) {
            val normalized = normalizeArabicDigits(raw).lowercase()
            if (walletKeywords.any { normalized.contains(it) }) continue

            for (curr in currencyMarkers) {
                val escaped = Regex.escape(curr)
                val r1 = Regex("""(\d+(?:\.\d+)?)\s*""" + escaped)
                r1.findAll(normalized).forEach { m ->
                    m.groupValues[1].toFloatOrNull()?.let { if (it > 0f) candidates.add(it) }
                }
                val r2 = Regex(escaped + """\s*(\d+(?:\.\d+)?)""")
                r2.findAll(normalized).forEach { m ->
                    m.groupValues[1].toFloatOrNull()?.let { if (it > 0f) candidates.add(it) }
                }
            }
        }

        // Pass 3: Bare numbers on offer bottom sheet (e.g. "4.50" or "7.00" next to coin icon)
        if (candidates.isEmpty()) {
            for (raw in texts) {
                val normalized = normalizeArabicDigits(raw).lowercase()
                if (normalized.contains("km") || normalized.contains("كم") ||
                    normalized.contains("min") || normalized.contains("دقيقة") || normalized.contains("د") ||
                    normalized.contains("★") || normalized.contains("rating") ||
                    walletKeywords.any { normalized.contains(it) }) {
                    continue
                }
                val r = Regex("""\b(\d+(?:\.\d+)?)\b""")
                r.findAll(normalized).forEach { m ->
                    val v = m.groupValues[1].toFloatOrNull()
                    if (v != null && v in 2.0f..350.0f) {
                        candidates.add(v)
                    }
                }
            }
        }

        return candidates.maxOrNull()
    }

    /**
     * Resolves the button container strictly.
     * Crucial: NEVER climbs past normal button bounds (height 60px to 260px) into the dialog/map root!
     */
    private fun resolveStrictButtonContainer(node: AccessibilityNodeInfo, screenHeight: Int): AccessibilityNodeInfo {
        var current: AccessibilityNodeInfo? = node
        var bestButton: AccessibilityNodeInfo = node

        while (current != null) {
            val r = Rect()
            current.getBoundsInScreen(r)

            // Button must be in lower half of the screen
            if (r.top >= screenHeight * 0.45) {
                // Standard button bounds: height between 60px and 260px, width >= 250px
                if (r.height() in 60..260 && r.width() >= 250) {
                    bestButton = current
                    if (current.isClickable) {
                        return current // Found the exact clickable button container! Stop climbing immediately!
                    }
                }
            } else if (r.height() > 300) {
                // Reached dialog card or bottom-sheet root! STOP climbing!
                break
            }
            val parent = current.parent ?: break
            current = parent
        }
        return bestButton
    }

    /**
     * Finds the Accept Button using keywords and view IDs, strictly bounded to avoid map taps.
     */
    private fun findAcceptButton(rootNode: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val screenHeight = resources.displayMetrics.heightPixels

        // 1. Search by Accept Keywords ("Accept Offer", "قبول", "موافق", etc.)
        val matchedNode = findNodeByKeywords(rootNode, acceptKeywords)
        if (matchedNode != null) {
            return resolveStrictButtonContainer(matchedNode, screenHeight)
        }

        // 2. Search by View IDs
        val acceptIdPatterns = listOf(
            "btn_accept", "button_accept", "order_accept", "btn_submit",
            "btn_confirm", "ride_accept", "accept_ride", "offer_accept",
            "bid_button", "action_button", "btn_agree", "btn_action"
        )
        val matchedById = findNodeByViewIds(rootNode, acceptIdPatterns)
        if (matchedById != null) {
            return resolveStrictButtonContainer(matchedById, screenHeight)
        }

        return null
    }

    /**
     * Finds swipe button ONLY if explicit swipe text is present on the button
     */
    private fun findSwipeButton(rootNode: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val screenHeight = resources.displayMetrics.heightPixels
        val matchedNode = findNodeByKeywords(rootNode, explicitSwipeKeywords) ?: return null
        return resolveStrictButtonContainer(matchedNode, screenHeight)
    }

    private fun findNodeByKeywords(node: AccessibilityNodeInfo?, keywords: List<String>): AccessibilityNodeInfo? {
        if (node == null) return null
        val text = (node.text?.toString() ?: "").lowercase()
        val desc = (node.contentDescription?.toString() ?: "").lowercase()

        for (kw in keywords) {
            val k = kw.lowercase()
            if (text.contains(k) || desc.contains(k)) {
                return node
            }
        }

        for (i in 0 until node.childCount) {
            val found = findNodeByKeywords(node.getChild(i), keywords)
            if (found != null) return found
        }
        return null
    }

    private fun findNodeByViewIds(node: AccessibilityNodeInfo?, idPatterns: List<String>): AccessibilityNodeInfo? {
        if (node == null) return null
        val viewId = (node.viewIdResourceName ?: "").lowercase()

        if (idPatterns.any { viewId.contains(it) }) {
            return node
        }

        for (i in 0 until node.childCount) {
            val found = findNodeByViewIds(node.getChild(i), idPatterns)
            if (found != null) return found
        }
        return null
    }

    /**
     * Executes BOTH standard Accessibility Click AND physical touchscreen tap gesture
     * at the exact button center.
     */
    private fun performClick(node: AccessibilityNodeInfo, toastMsg: String = "Driving Care: Auto-Accepted! 🚗⚡") {
        val rect = Rect()
        node.getBoundsInScreen(rect)

        // 1. Accessibility Action Click directly on target node and immediate parent
        var actionClicked = false
        if (node.isClickable) {
            actionClicked = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        if (!actionClicked && node.parent?.isClickable == true) {
            actionClicked = node.parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        // 2. Physical Screen Touch Tap at Exact Button Center
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && rect.width() > 0 && rect.height() > 0) {
            val clickPath = Path().apply {
                moveTo(rect.centerX().toFloat(), rect.centerY().toFloat())
            }
            // Crisp 50ms tap duration (Pure touch tap, prevents touch cancel or map pan)
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(clickPath, 0, 50))
                .build()
            dispatchGesture(gesture, null, null)
            Log.d(TAG, "Dispatched physical tap at (${rect.centerX()}, ${rect.centerY()}) [bounds=$rect, actionClicked=$actionClicked]")
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
            if (rect.width() > 40 && rect.height() > 20) {
                val startX = rect.left.toFloat() + (rect.width() * 0.15f)
                val endX = rect.right.toFloat() - (rect.width() * 0.15f)
                val centerY = rect.centerY().toFloat()

                val swipePath = Path().apply {
                    moveTo(startX, centerY)
                    lineTo(endX, centerY)
                }
                val gesture = GestureDescription.Builder()
                    .addStroke(GestureDescription.StrokeDescription(swipePath, 0, 250))
                    .build()
                dispatchGesture(gesture, null, null)
                Log.d(TAG, "Dispatched swipe-to-accept gesture across ($startX to $endX at y=$centerY)")

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
