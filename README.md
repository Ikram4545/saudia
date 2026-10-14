# Driving Care - Saudi Arabia Ride-Hailing Driver Assistant & Licensing System

## Project Overview
**Driving Care** is an enterprise driver automation bot and licensing platform designed for ride-hailing drivers in Saudi Arabia (operating on **Jeeny**, **Uber**, **Bolt**, and **Careem**).

The system consists of three integrated components:
1. **Android Client App (Flutter + Native Kotlin/Java Accessibility Engine)**: High-speed auto-accept driver assistant with anti-ban protections, price filtering, and region blacklists.
2. **Web Admin Licensing Dashboard (HTML5 / TailwindCSS / Vanilla JS)**: Centralized cloud portal for real-time driver management, instant 30-day key generation, 1-click renewal, remote suspension, and live driver activity tracking.
3. **High-Performance PHP/JSON Backend API**: Lightweight, zero-database-overhead backend hosted on LiteSpeed cPanel (`https://saudia.pixeltrio.com/api/`), featuring typo-tolerant key validation, heartbeat polling, trial generation, and secure admin token verification.

---

## Directory Structure
```
saudia/
├── cpanel_deploy/              # Complete Web Portal and Backend API files
│   ├── admin.html              # Web Admin Portal UI
│   ├── app.js                  # Admin Portal Frontend Engine & API Synchronization
│   ├── index.html              # Driver Landing Page & Documentation
│   ├── download.php            # Official APK Download Counter & Delivery
│   ├── .htaccess               # LiteSpeed Rewrite, CORS, and ModSecurity Rules
│   └── api/
│       ├── db.php              # Central JSON Database Helper & IP resolver
│       ├── login.php           # License Key Validation (Typo-Tolerant, Normalized)
│       ├── ping.php            # Heartbeat check & remote kill-switch
│       ├── trial.php           # 24-48 Hour Free Driver Trial Provisioner
│       ├── settings.php        # Dynamic filter settings sync
│       ├── admin_login.php     # Admin session authentication
│       ├── admin_drivers.php   # Driver list & real-time activity log endpoint
│       ├── admin_create_key.php # 30-day key generator & server database sync
│       ├── admin_delete_driver.php # Driver revocation endpoint
│       └── admin_toggle_driver.php # Driver status toggle (Active/Blocked)
├── flutter_driving_care/       # Complete Flutter Source Code
│   ├── lib/
│   │   └── main.dart           # Main Flutter App Controller, UI, & Licensing Client
│   ├── android/                # Native Android Kotlin/Java Accessibility Service
│   └── pubspec.yaml            # Project dependencies
├── build_driving_care_apk.py   # Automated Python APK Builder, Patcher, & Signer
├── prepare_and_sign_apk.py     # Keystore generation & signing verification
├── driving_care.keystore       # Production RSA signing keystore
└── driving_care_logo.jpg       # Brand logo
```

---

## Key Technical Breakthroughs & Fixes Implemented

### 1. Typo-Tolerant & Flexible License Verification
Saudi drivers frequently make keyboard typos when inputting license keys (e.g., using slashes `/` instead of hyphens `-`, Arabic keyboard spacing, or typing 4 ones instead of 2).
The backend `login.php` was upgraded with an intelligent normalizer:
- Automatically strips non-alphanumeric characters for matching (`DCNASIR11` matches `DC-NASIR-11`, `DC/NASIR/11`, `dc-nasir-11`, etc.).
- Tolerates optional `DC-` prefix (entering `NASIR-11` or `NASIR11` will resolve correctly).

### 2. ModSecurity Firewall Unblock (The Flutter Dart User-Agent Fix)
The Flutter mobile application makes HTTP requests using Dart's native `HttpClient`, which transmits `User-Agent: Dart/3.5 (dart:io)`.
The hosting server's LiteSpeed / ModSecurity web application firewall was intercepting all `Dart` user agents as potential automation bots and immediately replying with `HTTP 403 Forbidden` before requests could reach the PHP scripts.
**Resolution**:
- Added `SecRuleEngine Off` rules to `.htaccess` specifically disabling aggressive bot filtering on the API endpoints.
- Updated Flutter `HttpClient` to use custom User-Agent `DrivingCareApp/2.3` and increased network timeouts to 10 seconds.
- Verified that all mobile requests now return `HTTP 200 OK` instantaneously.

### 3. Bulletproof Admin Key Synchronization
Previously, creating a driver in the Admin Web Portal saved to browser `localStorage` but skipped the server API when the admin token was uninitialized.
**Resolution**:
- Updated `admin.html` and `app.js` to ensure session credentials (`X-Admin-Password: Ikram445@@` and persistent admin tokens) are attached to all key generation and deletion requests.
- All drivers created in the Admin Portal are guaranteed to sync to `driving_care_db.json` on the live server.

---

## Credentials & Access
- **Admin Portal**: `https://saudia.pixeltrio.com/admin`
- **Master Admin Username**: `Ikram`
- **Master Admin Password**: `Ikram445@@`
- **APK Download**: `https://saudia.pixeltrio.com/download.php`
- **Direct APK**: `https://saudia.pixeltrio.com/DrivingCare.apk`

---

## Latest Release & Commit Info (Fresh 14 October 2026)
- **Release Version**: Driving Care v2.4 (Production Release)
- **Date**: 14 October 2026
- **APK File**: `Driving_Care_v2.4_Production.apk` (22.08 MB)
- **Official Live Download**: `https://saudia.pixeltrio.com/download.html`
- **Direct Download Link**: `https://saudia.pixeltrio.com/DrivingCare.apk`
- **Official Keystore**: `driving_care.keystore` (Alias: `drivingcare`)
- **Key Updates**:
  1. Real Battery Optimization Permission (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)
  2. Real System Overlay Permission (`SYSTEM_ALERT_WINDOW`)
  3. Real Android 13/14 Notifications Permission (`POST_NOTIFICATIONS`) + Persistent Foreground Status Bar Notification
  4. Test Mode & Test Order Overlay completely purged
  5. Offline Ed25519 Cryptographic Licensing (`license_crypto.dart`) + Nasir Offline Whitelist (`DC-NASIR-11`)
  6. Heartbeat Grace Period (Never auto-locks on network timeout / drop)
  7. Android 13/14 Restricted Settings 1-Tap Bypass to App Info
  8. Startup crash resolved by retaining AndroidX / Coroutines ServiceLoader files in `META-INF/services/`

