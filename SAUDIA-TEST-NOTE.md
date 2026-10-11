# DRIVING CARE (SAUDIA) — PRODUCTION TEST & DEPLOYMENT REPORT

**Project:** Driving Care (Saudi Ride-Hailing Driver Auto-Accept Bot & Anti-Ban System)  
**Target Platforms:** Jeeny (Captain/Driver), Uber Driver, Bolt Driver  
**Region:** Kingdom of Saudi Arabia (Riyadh, Jeddah, Dammam, Mecca, Medina)  
**Lead Developer:** Ikram (WhatsApp: 03113154649)  
**Client / Owner:** Bilal (+966 53 419 9549)  
**Release Version:** v2.4 (Production Hardened)

---

## 1. Device Compatibility & Android 13/14 "Restricted Settings" Guide

### Why Android 13/14 Shows "App was denied" or Grayed-Out Accessibility:
Google introduced sideload security in Android 13 and Android 14. When an APK is downloaded via Chrome or WhatsApp, Android disables Accessibility Service by default and grays out the toggle.

### Step-by-Step Resolution (Built directly into the App UI):
1. Driver opens **Driving Care**. If Accessibility is OFF, a high-contrast banner appears.
2. Tap the button: **`Android 13/14 "Restricted Setting" Grayed out? Tap here`**.
3. This opens Android **App Info** for Driving Care (`Settings -> Apps -> Driving Care`).
4. Tap the **3 vertical dots (⋮)** in the top right corner.
5. Tap **"Allow restricted settings"** (Barah-e-karam restricted settings allow karein) and confirm biometric/PIN.
6. Return to **Accessibility -> Installed apps -> Driving Care** and turn the switch **ON**.

---

## 2. Samsung & Xiaomi Background Survival (Fix 1 & Fix 2)

### Real Native Checks:
- **Battery Optimization:** Linked to `PowerManager.isIgnoringBatteryOptimizations(packageName)`.
- **Display Overlay:** Linked to `Settings.canDrawOverlays(context)`.
- **Lifecycle Auto-Refresh:** Whenever the driver switches back to Driving Care from Android Settings, `WidgetsBindingObserver` automatically queries the OS and turns the card indicators green.

### Samsung Device Care Optimization:
- **Settings → Apps → Driving Care → Battery → Unrestricted**
- **Settings → Battery and Device Care → Battery → Background usage limits → Never sleeping apps → Add Driving Care**
- This ensures OneUI / Samsung Android 13/14 never kills the accessibility engine during long standby periods in Riyadh traffic.

---

## 3. Jeeny Ride-Hailing Package & Button Keyword Verification (Fix 6)

### Supported Driver Packages:
- `me.jeeny.driver` (Official Saudi Captain App)
- `com.easytaxi.driver` (Legacy EasyTaxi / Jeeny Engine)
- `com.jeeny.driver`
- `me.jeeny.captain`
- `com.ubercab.driver` (Uber Driver)
- `ee.mtakso.driver` (Bolt Driver KSA)

### Accessibility Service Configuration (`accessibility_service_config.xml`):
- Removed restrictive `android:packageNames` tag.
- Service now listens to all interactive window state changes, heads-up notifications, and floating overlays.

### Arabic & English Order Accept Keywords:
- **Arabic:** `قبول`, `قبول الطلب`, `قبول المشوار`, `تأكيد`, `تأكيد الطلب`, `استلام`, `طلب جديد`, `اضغط للقبول`, `اسحب للقبول`, `اسحب`
- **English:** `accept`, `tap to accept`, `confirm`, `take order`, `take ride`, `match`, `accept order`, `swipe to accept`, `slide to accept`
- **Eastern Arabic Digits:** Automatically normalized (`٠١٢٣٤٥٦٧٨٩` → `0-9`).
- **SAR Currency Parsing:** Supports `SAR`, `SR`, `ر.س`, `ريال`.

---

## 4. Cryptographic Offline Licensing & Zero-Firewall Guarantee (Fix 4, 5, 7)

### Problem Solved:
Saudi firewall and ISP network fluctuations frequently caused temporary network drops or 403 blocks, triggering false "Invalid License Key" lockouts.

### New Architecture:
1. **Ed25519 Cryptographic Signatures:**
   - Keys signed using Master Ed25519 private key seed.
   - Public Key embedded in Flutter client: `4d33b73ef90afd009626442d74ce1d593cd6db64f1d23b83d1ecbcb33a9588e9`.
   - Verified 100% locally on the driver's phone with zero network connection required.
   - Works fully in **Airplane Mode**.
2. **Pre-Authorized VIP Whitelist:**
   - `DC-NASIR-11` (Nasir)
   - `DC-NASIR-1111` (Nasir)
   - `DC-7300` (Nasir-hussain)
   - `DC-8921` (Tariq Al-Harbi)
   - `IKRAM-VIP` (Ikram Master Admin)
   - `BILAL-VIP` (Bilal Owner Admin)
   - `ADNAN-VIP` (Adnan Driver)
3. **Grace Period & Non-Blocking Telemetry:**
   - When network drops or server is unreachable, app enters 24-48h grace period and **NEVER locks the engine**.
   - Lock only triggers if server returns explicit HTTP 200 with `status: blocked` or `status: suspended`.
4. **Key Normalization:**
   - Sluggish slashes and typos (`dc/nasir/1111`, `DC-NASIR-1111`, `dcnasir1111`) are normalized across client, login.php, and ping.php.

---

## 5. Verification Checklist (16-Point Acceptance)

| # | Check | Status | Verification Detail |
|---|---|:---:|---|
| 1 | REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in Manifest | PASS | Verified in AndroidManifest.xml |
| 2 | SYSTEM_ALERT_WINDOW in Manifest | PASS | Verified in AndroidManifest.xml |
| 3 | FOREGROUND_SERVICE & WAKE_LOCK in Manifest | PASS | Verified in AndroidManifest.xml |
| 4 | MethodChannel Battery Opt Native Check | PASS | Real OS check via PowerManager |
| 5 | MethodChannel Overlay Native Check | PASS | Real OS check via Settings.canDrawOverlays |
| 6 | Native License Cache in SharedPreferences | PASS | Saved across app restarts & phone reboot |
| 7 | Zero TEST CARD UI in Codebase | PASS | Grep search returns 0 matches |
| 8 | Remove _showTestOrderOverlay | PASS | Completely eliminated |
| 9 | Offline Ed25519 License Verification | PASS | Verified with cryptography package |
| 10 | Legacy Whitelist Offline Activation | PASS | DC-NASIR-11 unlocks in Airplane Mode |
| 11 | Network Drop Grace Period (Heartbeat) | PASS | Zero lockouts on network drop / timeout |
| 12 | ping.php Key Normalizer | PASS | Live on cPanel with auto-registration |
| 13 | Live Permissions Dashboard Status Bar | PASS | Real-time status cards on dashboard |
| 14 | Android 13/14 App Info Quick Link | PASS | One-tap navigation to allow restricted settings |
| 15 | Release APK Signed with Official Keystore | PASS | Verified with apksigner v1, v2, v3 |
| 16 | GitHub & cPanel Deployment | PASS | Synced to cPanel and Git repository |

---
**Build Certified for Production Release by Builder.**
