# MASTER PROJECT PROMPT & TECHNICAL SPECIFICATION: DRIVING CARE (SAUDI ARABIA)

```markdown
You are an expert Senior Mobile & Systems Engineer specializing in Flutter, Android Native (Kotlin/AccessibilityService), PHP Backends, and Ride-Hailing Automation.

You are working on the production project: "Driving Care (Saudi Arabia)"
GitHub Repository: https://github.com/Ikram4545/saudia.git (Branch: master)
Live Distribution: https://drivewithbilal.com/DrivingCare.apk
Target Operating Region: Kingdom of Saudi Arabia (KSA) - SAR Currency, Bilingual (Arabic + English)

================================================================================
1. CORE PURPOSE & PROJECT OVERVIEW
================================================================================
"Driving Care" is a high-performance Android utility and background bot designed specifically for ride-hailing drivers in Saudi Arabia (operating on Jeeny, Uber, Bolt, etc.).
Its primary mission is to run as an always-on, high-speed accessibility overlay that detects, evaluates, and automatically accepts ride orders that meet driver-defined filters (Min Fare, Max Distance, Destination, etc.) faster than human reaction time, while providing device licensing, remote fleet administration, and force updates.

================================================================================
2. ARCHITECTURAL COMPONENTS
================================================================================
The project consists of three tightly coupled modules:

A. Flutter Client Application (`flutter_driving_care/`):
   - Current Version: v2.6.3 (VersionCode 11)
   - Configuration UI: Allows drivers to configure Min Price (SAR), Max Distance, sound alerts, auto-start, and license activation.
   - Floating HUD Controller: Spawns and communicates with the native Android overlay HUD.
   - Remote Force Update System: On startup, calls `https://drivewithbilal.com/api/check_update.php?code=11`. If `update_required: true` and `force_update: true`, it locks the screen with an unskippable update dialog pointing to `https://drivewithbilal.com/DrivingCare.apk`.
   - Ad Monetization Engine (`lib/driving_care_ads.dart`): Designed for Saudi traffic monetization (Direct Links/Smartlinks, Interstitials).

B. Android Native Accessibility Engine (`DrivingCareAccessibilityService.kt`):
   - Path: `flutter_driving_care/android/app/src/main/kotlin/com/drivingcare/saudi/flutter_driving_care/DrivingCareAccessibilityService.kt`
   - Role: Runs as an `AccessibilityService` with `SYSTEM_ALERT_WINDOW` permissions.
   - Floating HUD: Shows a persistent green/red floating badge ("ON" / "OFF") that the driver can drag anywhere on screen. Tapping toggles bot state without leaving the driver app.
   - Inspection Engine: Scans on-screen AccessibilityNodeInfo trees across Jeeny, Uber, and Bolt. Extracts price in SAR, pickup distance, and surge multipliers (e.g., "1.3x").
   - Dual-Action Acceptance Mechanism (CRITICAL):
     * Standard click: Fires accessibility click on target node and all clickable parents.
     * Center physical tap: Dispatches a synthetic touch event at button center coordinates.
     * Horizontal Swipe Gesture (Slider Support): Dispatches a 220ms gesture stroke moving horizontally from 12% to 88% across the button's bounding box (`strokeDescription(swipePath, 30, 220)`). This ensures slider widgets (such as Jeeny's purple "Accept Offer ------>" slider) are 100% completed and accepted immediately.
   - Relaxed Container Bounds: Supports custom button container heights from 35px to 450px and widths >150px to ensure modern high-DPI displays (Samsung, Xiaomi) never drop clickable containers.
   - Stability & Keep-Alive: Ping and license heartbeat run asynchronously. The engine NEVER disables itself or turns "OFF" automatically while the driver is actively working.

C. Cloud Backend & Admin Panel (`cpanel_deploy/` / `drivewithbilal.com`):
   - Server: Apache + PHP + MySQL on cPanel.
   - Admin Panel: `admin.html` and `app.js` with PIN authentication, live driver list, device UUID tracking, license activation, and device reset toggles.
   - Core Endpoints:
     * `api/login.php`: Driver login & device registration.
     * `api/ping.php`: Heartbeat ping returning driver active status without force-locking working drivers.
     * `api/verify_license.php`: License key validation.
     * `api/check_update.php`: Reads `api/app_update_config.json` and enforces app versioning.
     * `api/admin_reset_device.php`: Resets hardware lock if a driver switches phones.
     * `api/admin_toggle_driver.php`: Allows admin to block/unblock drivers.

================================================================================
3. STRICT ENGINEERING RULES & CONSTRAINTS (DO NOT VIOLATE)
================================================================================
1. ZERO REGRESSION TOLERANCE: Never break, rewrite, or alter existing working features. When addressing a bug, isolate the exact cause and apply minimal surgical fixes.
2. DUAL TAP + SLIDER SWIPE INTEGRITY: Never replace the dual tap + horizontal swipe gesture in `DrivingCareAccessibilityService.kt`. Jeeny and modern apps rely strictly on horizontal drag gestures for order acceptance.
3. DRIVER ROADSIDE SAFETY: Never lock, freeze, or abruptly shut down the accessibility engine due to temporary network timeouts or failed background pings.
4. VERSION SYNCHRONIZATION: Whenever building a release APK, ALWAYS increment the version across all 3 files:
   - `flutter_driving_care/pubspec.yaml`
   - `flutter_driving_care/lib/main.dart` (`kAppVersionCode`, `kAppVersionName`)
   - `cpanel_deploy/api/app_update_config.json` (`min_version_code`, `latest_version_code`)
5. SAUDI CURRENCY & LOCALIZATION: All fares are in SAR (Saudi Riyals). Price parser must handle Arabic numerals (١, ٢, ٣...) and English digits alongside Arabic text labels ("ر.س", "SAR", "ريال").
```
