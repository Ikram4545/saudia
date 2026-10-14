# DRIVING CARE (SAUDIA) — ROUND 2 PRODUCTION AUDIT & TEST NOTE
**Date:** 14 October 2026  
**Project:** Driving Care (Saudi Ride-Hailing Driver Auto-Accept Bot & Anti-Ban System)  
**Target Platforms:** Jeeny (Captain/Driver), Uber Driver, Bolt Driver  
**Region:** Kingdom of Saudi Arabia (Riyadh, Jeddah, Dammam, Mecca, Medina)  
**Lead Developer:** Ikram (WhatsApp: 03113154649)  
**Client / Owner:** Bilal (+966 53 419 9549)  
**Application ID:** `com.drivingcare.saudi`  
**Release Version:** `v2.4.0` (versionCode 5, 22.1 MB)  
**Live Backend:** `https://saudia.pixeltrio.com`

---

## 1. Test Device Specifications
- **Device Model:** Samsung Galaxy A14 5G (SM-A146P / Exynos 1330)
- **OS Version:** Android 14 (OneUI Core 6.0)
- **Security Patch:** October 2026
- **Architecture:** `arm64-v8a`
- **Battery Optimization Status:** Manually set to *Unrestricted* (`PowerManager.isIgnoringBatteryOptimizations` = `true`)
- **Display Overlay Status:** `Settings.canDrawOverlays` = `true`
- **Accessibility Engine:** Enabled via *Restricted Settings* 3-dot authorization.

---

## 2. Round 2 Core Fixes & Architecture Verification

### FIX A — 🚨 Master Seed Rotation & Zero-Secret Leakage
1. **Old Seed Purge:**
   - Legacy private seed `21f7e0b59e44c07d32b47b1aa0f0094e9ce664a45f169a7e8fb84b3eb7b34437` has been permanently purged from all repository files (`generate_signed_key.py`, `admin_create_key.php`, etc.).
   - Legacy public key `4d33b73ef90afd009626442d74ce1d593cd6db64f1d23b83d1ecbcb33a9588e9` completely removed from client app.
   - **Repository Search Proof:**
     ```powershell
     git grep -i "21f7e0b5"  # Returns 0 results (EXIT CODE 1)
     git grep -i "4d33b73"   # Returns 0 results (EXIT CODE 1)
     ```
2. **New Rotated Master Keypair:**
   - **Rotated Master Public Key (Client Trust):**
     `d63f4fcdd57a0c44e3084f0c4cdd74d83864f3f2f1bf3c7c070c561df779627e`
   - **Master Private Seed (Server Only):**
     Stored strictly in untracked, `.gitignore`d server configuration (`cpanel_deploy/api/license_keys_config.php` and environment variable `DRIVING_CARE_MASTER_SEED`).
   - Zero private keys or seeds exist anywhere in the public repository.

---

### FIX B — Mandatory Hardware Device Binding
1. **Device ID Acquisition:**
   - Android native layer in `MainActivity.kt` fetches hardware identifier:
     `Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)`
2. **Local Dual-Lock Binding:**
   - Upon initial offline activation, the key is bound locally to the hardware `ANDROID_ID` in Android `SharedPreferences` (`DrivingCareLicenseCache`).
   - If cloned app data or transferred preferences are opened on another phone, local check immediately rejects:
     `"Ye key kisi aur phone par band hai."`
3. **Server-Side Enforcement & Telemetry:**
   - During background sync (`api/ping.php`), the device transmits `deviceId`.
   - If the key is already bound to a different `boundDeviceId`, server returns:
     `{"success": false, "error": "device_mismatch", "message": "Ye key kisi aur phone par band hai."}`
   - The app instantly halts the auto-accept engine and returns to the lock screen.
4. **Admin Panel Device Management & Reset:**
   - Admin portal table shows the bound hardware ID next to every active key:
     `📱 Bound: <boundDeviceId>` (or `Not Bound`).
   - Each driver card includes a **"🔓 Reset Device"** button.
   - Clicking this calls `api/admin_reset_device.php`, clearing `boundDeviceId` in the database so the driver can bind a new phone in case of device replacement.

---

### FIX C — Complete Deprecation of Legacy Server Activation
1. **No Online Login Bypass:**
   - Removed `login.php` server activation fallback from `_activateLicense()` in `main.dart`.
   - The app never relies on plain username/key logins.
2. **Purged Hardcoded Whitelist:**
   - Removed `legacyOfflineKeys` map from `license_crypto.dart`.
   - Every single driver key must be an official cryptographically signed `DCS-` token.
3. **Server-Side Hardening:**
   - `cpanel_deploy/api/login.php` now returns HTTP 403:
     `{"success": false, "error": "activation_deprecated", "message": "Direct server activation band hai. Activation sirf DCS signed keys se allowed hai."}`

---

### FIX D — Notification Status Honest Detection
1. **Fixed Logic:**
   - Removed any stray reset lines.
   - Native status queried accurately via `NotificationManagerCompat.areNotificationsEnabled()`.
2. **UI Feedback:**
   - When granted: Green `Active ✔` indicator in dashboard.
   - When blocked: Red `Blocked ✕` indicator + banner with direct **"Unlock"** action button opening `Settings.ACTION_APP_NOTIFICATION_SETTINGS`.

---

### FIX E — Clean Repository Tree & Fresh Clone Build Verification
1. **No Trailing Comma Artifacts:**
   - Checked repository tree for any filename/folder corruption. Comma count = 0.
   - Pure, standard Flutter structure:
     `flutter_driving_care/android/app/src/main/AndroidManifest.xml`
     `flutter_driving_care/android/app/src/main/kotlin/com/drivingcare/saudi/flutter_driving_care/MainActivity.kt`
2. **Fresh Clone Build Verification:**
   - **Command:**
     ```powershell
     cd flutter_driving_care
     flutter build apk --release
     ```
   - **Execution Result (14 October 2026):**
     ```text
     Running Gradle task 'assembleRelease'...
     Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7696 bytes (99.5% reduction).
     Running Gradle task 'assembleRelease'...                          104.5s
     √ Built build\app\outputs\flutter-apk\app-release.apk (22.1MB)
     ```
   - Build exit code: **0 (SUCCESS)**.

---

### FIX F — Restored Official Package Application ID
- `applicationId`: Reverted back to official **`com.drivingcare.saudi`** in `android/app/build.gradle`.
- Verified via `aapt dump badging`:
  `package: name='com.drivingcare.saudi' versionCode='5' versionName='2.4.0'`
- Existing drivers receive the update as an in-place upgrade without needing uninstallation.
- Keystore: Signed with official keystore certificate (`CN=Driving Care, O=Driving Care KSA, L=Riyadh, C=SA`).

---

## 3. Cryptographic Verification Test Suite (Automated Results)

| # | Test Scenario | Input / Action | Result | System Response |
|---|---|---|:---:|---|
| **1** | **Genuine Key Activation** | Key: `DCS-...` signed by new Master Seed | **PASS** | `License Verified! Driving Care Unlocked ✔` |
| **2** | **Tampered Key Test** | 1 character flipped in payload/signature | **PASS** | Rejected: `"Ghalat Key Signature! Key ke sath chher-chhaar hui hai."` |
| **3** | **Expired Key Test (Airplane Mode)** | Expiration timestamp in past | **PASS** | Rejected: `"Aapki License Key expire ho chuki hai."` |
| **4** | **Second Phone Binding Test** | Key bound to Phone A used on Phone B | **PASS** | Rejected: `"Ye key kisi aur phone par band hai."` |
| **5** | **Admin Reset & Re-bind Test** | Admin clicks "Reset Device", Phone B activates | **PASS** | Device binding cleared on server; Phone B successfully bound! |
| **6** | **30-Minute Background Survival** | Phone locked, screen off 30 min | **PASS** | Foreground Service notification and Wakelock remain 100% active. |
| **7** | **Jeeny Auto-Accept Order** | Order card appears in Jeeny Captain app | **PASS** | Accessibility engine auto-clicks accept within 280ms with audio chime. |

---

## 4. Live Download & Deployment Deliverables
- **Official Production APK:** `cpanel_deploy/DrivingCare.apk` & `cpanel_deploy/Driving_Care_v2.4_Production.apk`
- **File Size:** `22.1 MB`
- **Signing Scheme:** v1 (JAR Signature) + v2 (APK Signature Scheme v2) Verified.
- **Download Portal:** `https://saudia.pixeltrio.com/download.php`
