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
import java.net.URL
import java.net.HttpURLConnection
import org.json.JSONObject



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

    // Remote 8-Second Native Kill-Switch Check
    private val heartbeatHandler = Handler(Looper.getMainLooper())
    private var isHeartbeatChecking = false
    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            checkLicenseStatusBackground()
            heartbeatHandler.postDelayed(this, 8000)
        }
    }



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



            try {
                startForeground(NOTIF_ID, notification)
            } catch (e: Throwable) {
                notificationManager.notify(NOTIF_ID, notification)
            }

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
        heartbeatHandler.removeCallbacks(heartbeatRunnable)
        heartbeatHandler.post(heartbeatRunnable)
    }



    override fun onUnbind(intent: android.content.Intent?): Boolean {

        isServiceRunning = false

        instance = null

        teardownHud()
        heartbeatHandler.removeCallbacks(heartbeatRunnable)

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
        heartbeatHandler.removeCallbacks(heartbeatRunnable)

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
        val isLicenseActive = prefs.getBoolean("license_active", false)
        val isEngineOn = prefs.getBoolean("run_auto_engine", false)
        if (!isLicenseActive || !isEngineOn) return



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

    /**
     * Advanced Arabic text normalizer: strips diacritics, unifies Alifs,
     * Taa Marbuta, Alif Maqsura, and Eastern Arabic digits for 100% accurate matching.
     */
    private fun normalizeArabicText(input: String): String {
        var s = normalizeArabicDigits(input)
        // Strip Arabic diacritics (tashkeel: fatha, damma, kasra, shadda, sukun, tanween)
        s = s.replace(Regex("""[\u064B-\u065F\u0670]"""), "")
        // Normalize alifs: أ, إ, آ, ٱ -> ا
        s = s.replace(Regex("""[أإآٱ]"""), "ا")
        // Normalize taa marbuta: ة -> ه
        s = s.replace('ة', 'ه')
        // Normalize alif maqsura: ى -> ي
        s = s.replace('ى', 'ي')
        // Normalize Farsi/Urdu Kaf/Yeh
        s = s.replace('ك', 'ك').replace('ي', 'ي')
        return s.trim().lowercase()
    }

    /**
     * Comprehensive Riyadh & Saudi Area Dictionary.
     * Maps English transliterations, abbreviations, and Arabic variations
     * for 50+ major Saudi neighborhoods, so Jeeny's Arabic screen always matches.
     */
    private fun extractLocationKeywords(rawLocation: String): List<String> {
        val keywords = mutableListOf<String>()
        val parts = rawLocation.split(Regex("""[()/,\-]"""))
        for (part in parts) {
            val clean = part.trim().lowercase()
            if (clean.length >= 2) {
                keywords.add(clean)
                keywords.add(normalizeArabicText(clean))
            }
        }

        val lower = rawLocation.lowercase()
        val norm = normalizeArabicText(rawLocation)

        // 1. Airport / King Khalid Airport
        if (lower.contains("airport") || norm.contains("مطار") || lower.contains("khalid")) {
            keywords.addAll(listOf("airport", "مطار", "المطار", "الملك خالد", "مطار الملك خالد", "king khalid"))
        }
        // 2. Bat'ha
        if (lower.contains("batha") || lower.contains("bat'ha") || norm.contains("بطحا")) {
            keywords.addAll(listOf("batha", "bat'ha", "al batha", "بطحاء", "البطحاء", "بطحا", "البطحا"))
        }
        // 3. Shamisi
        if (lower.contains("shamisi") || lower.contains("shumaisi") || norm.contains("شميسي")) {
            keywords.addAll(listOf("shamisi", "al shamisi", "shumaisi", "الشميسي", "شميسي"))
        }
        // 4. Manfuhah
        if (lower.contains("manfuhah") || lower.contains("manfuha") || norm.contains("منفوح")) {
            keywords.addAll(listOf("manfuhah", "manfuha", "منفوحة", "منفوحه", "المنفوحة", "المنفوحه"))
        }
        // 5. Railway / Station
        if (lower.contains("railway") || lower.contains("train") || norm.contains("قطار")) {
            keywords.addAll(listOf("railway", "train", "قطار", "القطار", "محطة القطار", "محطه القطار", "محطة قطار", "sar station", "سار"))
        }
        // 6. Safarat / Diplomatic Quarter
        if (lower.contains("safarat") || lower.contains("diplomatic") || norm.contains("سفارات") || norm.contains("دبلوماس")) {
            keywords.addAll(listOf("safarat", "al safarat", "السفارات", "سفارات", "حي السفارات", "diplomatic", "الدبلوماسي"))
        }
        // 7. KAFD / Financial District
        if (lower.contains("kafd") || norm.contains("كافد") || norm.contains("المالي")) {
            keywords.addAll(listOf("kafd", "كافد", "المالي", "مركز الملك عبدالله المالي"))
        }
        // 8. Al Narjis
        if (lower.contains("narjis") || norm.contains("نرجس")) {
            keywords.addAll(listOf("narjis", "al narjis", "نرجس", "النرجس"))
        }
        // 9. Al Yasmin
        if (lower.contains("yasmin") || lower.contains("yasmeen") || norm.contains("ياسمين")) {
            keywords.addAll(listOf("yasmin", "yasmeen", "al yasmin", "ياسمين", "الياسمين"))
        }
        // 10. Al Malaz
        if (lower.contains("malaz") || norm.contains("ملز")) {
            keywords.addAll(listOf("malaz", "al malaz", "al-malaz", "ملز", "الملز"))
        }
        // 11. Al Olaya
        if (lower.contains("olaya") || lower.contains("ulaya") || norm.contains("عليا")) {
            keywords.addAll(listOf("olaya", "al olaya", "ulaya", "عليا", "العليا"))
        }
        // 12. Al Sahafa
        if (lower.contains("sahafa") || lower.contains("sahafah") || norm.contains("صحاف")) {
            keywords.addAll(listOf("sahafa", "sahafah", "al sahafa", "صحافة", "الصحافة", "صحافه", "الصحافه"))
        }
        // 13. Al Aqiq
        if (lower.contains("aqiq") || lower.contains("aqeeq") || norm.contains("عقيق")) {
            keywords.addAll(listOf("aqiq", "aqeeq", "al aqiq", "عقيق", "العقيق"))
        }
        // 14. Al Ghadir
        if (lower.contains("ghadir") || lower.contains("ghadeer") || norm.contains("غدير")) {
            keywords.addAll(listOf("ghadir", "ghadeer", "al ghadir", "غدير", "الغدير"))
        }
        // 15. Al Nakheel
        if (lower.contains("nakheel") || lower.contains("nakhil") || norm.contains("نخيل")) {
            keywords.addAll(listOf("nakheel", "al nakheel", "نخيل", "النخيل"))
        }
        // 16. Al Rawdah
        if (lower.contains("rawdah") || lower.contains("rowdah") || norm.contains("روض")) {
            keywords.addAll(listOf("rawdah", "al rawdah", "روضة", "الروضة", "روضه", "الروضه"))
        }
        // 17. Al Hamra
        if (lower.contains("hamra") || lower.contains("hamraa") || norm.contains("حمرا")) {
            keywords.addAll(listOf("hamra", "al hamra", "حمراء", "الحمراء", "حمرا", "الحمرا"))
        }
        // 18. Al Munsiyah
        if (lower.contains("munsiyah") || lower.contains("mounsiya") || norm.contains("مونس") || norm.contains("منس")) {
            keywords.addAll(listOf("munsiyah", "mounsiya", "al munsiyah", "مونسية", "المونسية", "مونسيه", "المونسيه"))
        }
        // 19. Al Yarmouk
        if (lower.contains("yarmouk") || lower.contains("yarmuk") || norm.contains("يرموك")) {
            keywords.addAll(listOf("yarmouk", "yarmuk", "al yarmouk", "يرموك", "اليرموك"))
        }
        // 20. Al Shifa
        if (lower.contains("shifa") || lower.contains("shefa") || norm.contains("شفا")) {
            keywords.addAll(listOf("shifa", "al shifa", "شفاء", "الشفاء", "شفا", "الشفا"))
        }
        // 21. Al Aziziyah
        if (lower.contains("aziziyah") || lower.contains("azizia") || norm.contains("عزيزي")) {
            keywords.addAll(listOf("aziziyah", "al aziziyah", "عزيزية", "العزيزية", "عزيزيه", "العزيزيه"))
        }
        // 22. Al Sulaimaniyah
        if (lower.contains("sulaimaniyah") || lower.contains("sulaymaniyah") || norm.contains("سليماني")) {
            keywords.addAll(listOf("sulaimaniyah", "al sulaimaniyah", "سليمانية", "السليمانية", "سليمانيه", "السليمانيه"))
        }
        // 23. Al Waha
        if (lower.contains("waha") || lower.contains("al waha") || norm.contains("واح")) {
            keywords.addAll(listOf("waha", "al waha", "واحة", "الواحة", "واحه", "الواحه"))
        }
        // 24. Al Muruj
        if (lower.contains("muruj") || lower.contains("morooj") || norm.contains("مروج")) {
            keywords.addAll(listOf("muruj", "morooj", "al muruj", "مروج", "المروج"))
        }
        // 25. Al Worood
        if (lower.contains("worood") || lower.contains("wurud") || norm.contains("ورود")) {
            keywords.addAll(listOf("worood", "al worood", "ورود", "الورود"))
        }
        // 26. Al Raed
        if (lower.contains("raed") || lower.contains("al raed") || norm.contains("رائد")) {
            keywords.addAll(listOf("raed", "al raed", "رائد", "الرائد"))
        }
        // 27. Al Rahmaniyah
        if (lower.contains("rahmaniyah") || norm.contains("رحماني")) {
            keywords.addAll(listOf("rahmaniyah", "al rahmaniyah", "رحمانية", "الرحمانية", "رحمانيه", "الرحمانيه"))
        }
        // 28. King Fahd District
        if (lower.contains("king fahd") || norm.contains("الملك فهد")) {
            keywords.addAll(listOf("king fahd", "الملك فهد", "حي الملك فهد"))
        }
        // 29. Al Khalidiyah
        if (lower.contains("khalidiyah") || norm.contains("خالدي")) {
            keywords.addAll(listOf("khalidiyah", "al khalidiyah", "خالدية", "الخالدية", "خالديه", "الخالديه"))
        }
        // 30. Al Faisaliyah
        if (lower.contains("faisaliyah") || norm.contains("فيصلي")) {
            keywords.addAll(listOf("faisaliyah", "al faisaliyah", "فيصلية", "الفيصلية", "فيصليه", "الفيصليه"))
        }
        // 31. Al Naseem
        if (lower.contains("naseem") || lower.contains("nasim") || norm.contains("نسيم")) {
            keywords.addAll(listOf("naseem", "nasim", "al naseem", "نسيم", "النسيم", "النسيم الغربي", "النسيم الشرقي"))
        }
        // 32. Al Nadheem
        if (lower.contains("nadheem") || lower.contains("nadim") || norm.contains("نظيم")) {
            keywords.addAll(listOf("nadheem", "al nadheem", "نظيم", "النظيم"))
        }
        // 33. Al Khaleej
        if (lower.contains("khaleej") || norm.contains("خليج")) {
            keywords.addAll(listOf("khaleej", "al khaleej", "خليج", "الخليج"))
        }
        // 34. Al Nahdah
        if (lower.contains("nahdah") || norm.contains("نهض")) {
            keywords.addAll(listOf("nahdah", "al nahdah", "نهضة", "النهضة", "نهضه", "النهضه"))
        }
        // 35. Al Janadriyah
        if (lower.contains("janadriyah") || norm.contains("جنادري")) {
            keywords.addAll(listOf("janadriyah", "al janadriyah", "جنادرية", "الجنادرية", "جنادريه", "الجنادريه"))
        }
        // 36. Tuwaiq
        if (lower.contains("tuwaiq") || lower.contains("tuwayq") || norm.contains("طويق")) {
            keywords.addAll(listOf("tuwaiq", "tuwayq", "al tuwaiq", "طويق", "حي طويق"))
        }
        // 37. Dhahrat Laban
        if (lower.contains("laban") || norm.contains("لبن")) {
            keywords.addAll(listOf("laban", "dhahrat laban", "لبن", "ظهرة لبن", "ضهرة لبن", "حي لبن"))
        }
        // 38. Al Arid
        if (lower.contains("arid") || lower.contains("areed") || norm.contains("عارض")) {
            keywords.addAll(listOf("arid", "al arid", "عارض", "العارض"))
        }
        // 39. Al Rimal
        if (lower.contains("rimal") || lower.contains("reemal") || norm.contains("رمال")) {
            keywords.addAll(listOf("rimal", "al rimal", "رمال", "الرمال"))
        }
        // 40. Al Qirawan
        if (lower.contains("qirawan") || lower.contains("qairawan") || norm.contains("قيروان")) {
            keywords.addAll(listOf("qirawan", "al qirawan", "قيروان", "القيروان"))
        }
        // 41. Hittin
        if (lower.contains("hittin") || lower.contains("hateen") || norm.contains("حطين")) {
            keywords.addAll(listOf("hittin", "hateen", "حطين", "حي حطين"))
        }
        // 42. Al Malqa
        if (lower.contains("malqa") || norm.contains("ملقا")) {
            keywords.addAll(listOf("malqa", "al malqa", "ملقا", "الملقا"))
        }
        // 43. Diriyah
        if (lower.contains("diriyah") || lower.contains("dariya") || norm.contains("درعي")) {
            keywords.addAll(listOf("diriyah", "al diriyah", "درعية", "الدرعية", "درعيه", "الدرعيه"))
        }
        // 44. Al Suwaidi
        if (lower.contains("suwaidi") || lower.contains("swidi") || norm.contains("سويدي")) {
            keywords.addAll(listOf("suwaidi", "al suwaidi", "سويدي", "السويدي"))
        }
        // 45. Al Uraija
        if (lower.contains("uraija") || lower.contains("arja") || norm.contains("عريجا")) {
            keywords.addAll(listOf("uraija", "al uraija", "عريجاء", "العريجاء", "عريجا"))
        }
        // 46. Al Falah
        if (lower.contains("falah") || norm.contains("فلاح")) {
            keywords.addAll(listOf("falah", "al falah", "فلاح", "الفلاح"))
        }
        // 47. Al Taawun
        if (lower.contains("taawun") || lower.contains("taawon") || norm.contains("تعاون")) {
            keywords.addAll(listOf("taawun", "al taawun", "تعاون", "التعاون"))
        }
        // 48. Al Izdihar
        if (lower.contains("izdihar") || norm.contains("ازدهار")) {
            keywords.addAll(listOf("izdihar", "al izdihar", "ازدهار", "الازدهار"))
        }
        // 49. Al Quds
        if (lower.contains("quds") || norm.contains("قدس")) {
            keywords.addAll(listOf("quds", "al quds", "قدس", "القدس"))
        }
        // 50. Qurtubah
        if (lower.contains("qurtubah") || lower.contains("qurtoba") || norm.contains("قرطب")) {
            keywords.addAll(listOf("qurtubah", "qurtoba", "al qurtubah", "قرطبة", "القرطبة", "قرطبه", "القرطبه"))
        }
        // 51. Granada
        if (lower.contains("granada") || lower.contains("garnata") || norm.contains("غرناط")) {
            keywords.addAll(listOf("granada", "garnata", "غرناطة", "الغرناطة", "غرناطه", "الغرناطه"))
        }

        // Add normalized versions of all keywords to catch variations
        val enriched = mutableListOf<String>()
        for (kw in keywords) {
            val clean = kw.trim().lowercase()
            if (clean.isNotBlank()) {
                enriched.add(clean)
                enriched.add(normalizeArabicText(clean))
                if (!clean.startsWith("حي")) {
                    enriched.add("حي $clean")
                    enriched.add("حي " + normalizeArabicText(clean))
                }
            }
        }
        return enriched.distinct()
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
        val normArabicFullScreen = normalizeArabicText(rawFullScreenText)

        // Read configured rules (with generous defaults)
        val minPrice = prefs.getFloat("min_price", 10f)
        val maxPrice = prefs.getFloat("max_price", 200f)
        val autoReject = prefs.getBoolean("auto_reject", false)
        val blockedLocations = prefs.getStringSet("blocked_locations", emptySet()) ?: emptySet()
        val avoidWords = prefs.getStringSet("avoid_words", emptySet()) ?: emptySet()

        // 1. Comprehensive Location Blocking Check (Bilingual Arabic + English)
        var isLocationBlocked = false
        var matchedBlockedKeyword = ""
        var matchedSourceRule = ""

        // Check configured blocked locations
        for (blocked in blockedLocations) {
            val keywords = extractLocationKeywords(blocked)
            for (kw in keywords) {
                val kwClean = kw.trim().lowercase()
                val kwNorm = normalizeArabicText(kw)
                if (kwClean.isNotBlank() && (normalizedText.contains(kwClean) || normArabicFullScreen.contains(kwNorm))) {
                    isLocationBlocked = true
                    matchedBlockedKeyword = kwClean
                    matchedSourceRule = blocked
                    Log.d(TAG, "⛔ Blocked Location Detected: '$kwClean' (Rule: '$blocked')")
                    break
                }
            }
            if (isLocationBlocked) break
        }

        // Check avoid words (also expanded bilingually so English inputs match Arabic screens)
        if (!isLocationBlocked) {
            for (avoid in avoidWords) {
                val keywords = extractLocationKeywords(avoid)
                for (kw in keywords) {
                    val kwClean = kw.trim().lowercase()
                    val kwNorm = normalizeArabicText(kw)
                    if (kwClean.isNotBlank() && (normalizedText.contains(kwClean) || normArabicFullScreen.contains(kwNorm))) {
                        isLocationBlocked = true
                        matchedBlockedKeyword = kwClean
                        matchedSourceRule = avoid
                        Log.d(TAG, "⛔ Avoid Word Detected: '$kwClean' (Rule: '$avoid')")
                        break
                    }
                }
                if (isLocationBlocked) break
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

            // Price parsed or proceeded to accept offer

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

            // Button must be in lower 65% of screen
            if (r.top >= screenHeight * 0.35) {
                // Generous bounds for modern high-DPI screens: height 35px..450px, width >= 150px
                if (r.height() in 35..450 && r.width() >= 150) {
                    bestButton = current
                    if (current.isClickable) {
                        return current
                    }
                }
            } else if (r.height() > screenHeight * 0.6) {
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

        private fun performClick(node: AccessibilityNodeInfo, toastMsg: String = "Driving Care: Auto-Accepted! 🟢") {
        val rect = Rect()
        node.getBoundsInScreen(rect)

        // 1. Accessibility Action Click directly on target node and all clickable parents
        var actionClicked = false
        var p: AccessibilityNodeInfo? = node
        while (p != null) {
            if (p.isClickable) {
                actionClicked = p.performAction(AccessibilityNodeInfo.ACTION_CLICK) || actionClicked
            }
            p = p.parent
        }

        // 2. Physical Screen Touch: BOTH Center Tap AND Horizontal Slider Swipe!
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && rect.width() > 0 && rect.height() > 0) {
            val centerY = rect.centerY().toFloat()
            val startX = rect.left.toFloat() + (rect.width() * 0.12f)
            val endX = rect.right.toFloat() - (rect.width() * 0.12f)

            // A. Physical Center Tap (for standard buttons)
            val tapPath = Path().apply {
                moveTo(rect.centerX().toFloat(), centerY)
            }
            val tapGesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(tapPath, 0, 50))
                .build()
            dispatchGesture(tapGesture, null, null)

            // B. Horizontal Drag/Swipe across the button (for sliders / swipe-to-accept)
            val swipePath = Path().apply {
                moveTo(startX, centerY)
                lineTo(endX, centerY)
            }
            val swipeGesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(swipePath, 30, 220))
                .build()
            dispatchGesture(swipeGesture, null, null)

            Log.d(TAG, "Dispatched TAP and SLIDER SWIPE across ($startX to $endX at y=$centerY) [bounds=$rect, actionClicked=$actionClicked]")
        }

        // Show Instant Toast on screen so driver sees the bot working!
        try {
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(applicationContext, toastMsg, Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {}
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



    fun refreshHud() {

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
        val isLicenseActive = prefs.getBoolean("license_active", false)
        val isEngineOn = prefs.getBoolean("run_auto_engine", false)
        hudView?.background = hudBackground(isLicenseActive && isEngineOn)
        hudView?.text = if (!isLicenseActive) "🔒" else if (isEngineOn) "ON" else "OFF"
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
        val isLicenseActive = prefs.getBoolean("license_active", false)
        if (!isLicenseActive) {
            prefs.edit().putBoolean("run_auto_engine", false).apply()
            updateHudColor()
            showStatusNotification("Driving Care LOCKED 🔒 - Valid License Required")
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(
                    applicationContext,
                    "Driving Care LOCKED 🔒 - Admin revoked key",
                    Toast.LENGTH_LONG
                ).show()
            }
            return
        }

        val newState = !prefs.getBoolean("run_auto_engine", false)
        prefs.edit().putBoolean("run_auto_engine", newState).apply()
        updateHudColor()
        showStatusNotification(
            if (newState) {
                "Autopilot Active – Monitoring Jeeny & Ride Requests"
            } else {
                "Autopilot Paused – tap the floating button to resume"
            }
        )
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(
                applicationContext,
                if (newState) "Autopilot ON" else "Autopilot OFF",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    /**
     * Background Native Kill-Switch:
     * Pings the server every 8 seconds even if Flutter app is minimized/closed!
     * If Bilal/Admin deletes or resets key in Admin Panel, accessibility clicker
     * is IMMEDIATELY locked within 1-8 seconds!
     */
    private fun checkLicenseStatusBackground() {
        if (isHeartbeatChecking) return
        isHeartbeatChecking = true
        Thread {
            try {
                val licPrefs = getSharedPreferences("DrivingCareLicenseCache", Context.MODE_PRIVATE)
                val key = licPrefs.getString("key", null)
                val isLicenseActive = prefs.getBoolean("license_active", false)

                if (key.isNullOrBlank()) {
                    if (isLicenseActive) {
                        lockBotNative("License not found.")
                    }
                    isHeartbeatChecking = false
                    return@Thread
                }

                val deviceId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN_DEVICE"
                val configPrefs = getSharedPreferences("DrivingCareAppConfig", Context.MODE_PRIVATE)
                val serverUrl = configPrefs.getString("server_url", "https://drivewithbilal.com") ?: "https://drivewithbilal.com"

                val url = URL("$serverUrl/api/ping.php")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                conn.setRequestProperty("User-Agent", "DrivingCareApp/2.5")
                conn.connectTimeout = 6000
                conn.readTimeout = 6000
                conn.doOutput = true

                val currentVersionCode = try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        packageManager.getPackageInfo(packageName, 0).longVersionCode.toInt()
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0).versionCode
                    }
                } catch (e: Exception) {
                    10
                }

                val payload = JSONObject().apply {
                    put("key", key)
                    put("deviceId", deviceId)
                    put("device", "Android ($deviceId)")
                    put("versionCode", currentVersionCode)
                }

                conn.outputStream.use { os ->
                    os.write(payload.toString().toByteArray(Charsets.UTF_8))
                }

                val responseCode = conn.responseCode
                if (responseCode == 200) {
                    val body = conn.inputStream.bufferedReader().readText()
                    val json = JSONObject(body)
                    val success = json.optBoolean("success", false)
                    val lock = json.optBoolean("lock", false)
                    val status = json.optString("status", "").lowercase()
                    val error = json.optString("error", "").lowercase()

                    // If it is an update notification, do NOT lock background accessibility service while driver is on the road
                    if (error == "update_required" || json.optBoolean("force_update", false)) {
                        Log.i(TAG, "Update available on server - background service continues smoothly.")
                    } else if (lock || status == "expired" || status == "suspended" || status == "blocked" || status == "inactive" || error == "key_deleted") {
                        val msg = json.optString("message", "License admin ki taraf se band kar diya gaya hai.")
                        lockBotNative(msg)
                    } else if (success) {
                        // Key is active and valid
                        if (!isLicenseActive) {
                            prefs.edit().putBoolean("license_active", true).apply()
                            Handler(Looper.getMainLooper()).post {
                                updateHudColor()
                            }
                        }
                    }
                } else if (responseCode == 401 || responseCode == 403 || responseCode == 404) {
                    // DO NOT LOCK: Transient network, VPN, or cPanel firewall blocks must never shut off the bot while driving!
                    Log.w(TAG, "Native heartbeat network ping returned code $responseCode - ignoring transient error to prevent false lockout.")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Native heartbeat network ping error: ${e.message}")
            } finally {
                isHeartbeatChecking = false
            }
        }.start()
    }

    private fun lockBotNative(reason: String) {
        Handler(Looper.getMainLooper()).post {
            Log.e(TAG, "KILL-SWITCH ACTIVATED IN NATIVE ACCESSIBILITY SERVICE: $reason")
            prefs.edit()
                .putBoolean("run_auto_engine", false)
                .putBoolean("license_active", false)
                .apply()
            getSharedPreferences("DrivingCareLicenseCache", Context.MODE_PRIVATE)
                .edit()
                .clear()
                .apply()
            updateHudColor()
            showStatusNotification("Driving Care LOCKED 🔒 - $reason")
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

