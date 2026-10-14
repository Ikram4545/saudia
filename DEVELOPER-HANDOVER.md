# Driving Care v2.5.0 — Developer Handover (Muse ki edits)

Ye package GitHub repo `Ikram4545/Software-Apps` ke `saudia/` folder ki **sab se taaza halat (commit 09b1315)** par bana hai. Is mein sirf wohi files hain jo badli ya nayi bani hain — baqi poora project repo wala hi rahega. Har file ko usi path par replace/add karna hai jo neeche likha hai.

## Kya naya hua — file by file

### 1. Jeeny khud khule — Notification Listener (NAYI file)
`flutter_driving_care/android/app/src/main/kotlin/com/drivingcare/saudi/flutter_driving_care/DrivingCareNotificationListener.kt`
- Jeeny/Uber/Bolt/Careem ki **order notification** aate hi woh app khud samne aa jata hai, phir maujooda accessibility engine order accept karta hai. Phone jeb mein ho ya Jeeny band ho — farq nahi parta.
- Pehla rasta notification ke **apne contentIntent** ko chalana hai (Android ise driver ke tap jesa maanta hai, is liye Android 10–14 ki background-launch pabandi is par nahi lagti). Wo na mile to app ka launch intent fallback hai.
- Hifazat: sirf tab chalega jab (a) license active ho, (b) engine ON ho, (c) "Notification par Jeeny khud khule" wala switch ON ho. Persistent "you are online" wali notifications ko ignore karta hai. Ek hi app ko 10 second ke andar dobara nahi kholta.

### 2. Floating chhota button (HUD)
`DrivingCareAccessibilityService.kt` (HUD wala hissa aakhir mein add hai)
- Har app ke upar chhota gol **"DC" button**: sabz (green) = engine ON, laal (red) = engine OFF.
- **Tap** = engine on/off. **Drag** = jaga badalna (jaga yaad rehti hai).
- Button sirf tab dikhega jab accessibility ON ho + overlay permission mili ho + app ke andar "Floating button" switch ON ho.

### 3. MainActivity — naye channel methods
`MainActivity.kt`
- `isNotificationListenerEnabled`, `openNotificationListenerSettings`, `getNativeFlags` add hue.
- `syncSettings` ab har key sirf tab likhta hai jab bheji gayi ho (partial sync se purani settings kharab nahi hotin) + naye flags: `licenseActive`, `showFloatingButton`, `autoLaunchOnNotification`.

### 4. AndroidManifest
`AndroidManifest.xml` — notification listener service ka elan add hai (`Driving Care Order Alerts`).

### 5. App (Flutter) — main.dart
- Dashboard par naya **"Jeeny Auto-Open" card**: asal status (ON/OFF), ek tap par Notification Access ki settings, aur step-by-step guide dialog (Android 13/14 par switch gray ho to "Allow restricted settings" wala rasta bhi usi guide mein hai).
- Card mein 2 switch: "Notification par Jeeny khud khule" aur "Floating button".
- Engine ki asal halat ab native side se uthai jati hai — floating button se OFF kiya ho to app khulne par zabardasti ON nahi hota.
- **Device binding aur sakht:** purane cache (bina binding wale) par pehli baar app khulte hi key usi phone se bandh jati hai (muddat aage nahi barhti — remaining din hi save hote hain).
- **Trial device-bound:** app trial ke liye deviceId bhejti hai; server mana kare to trial nahi milta.

### 6. Trial server — cpanel_deploy/api/trial.php
- Ek device = ek hi trial. Trial chal raha ho to wahi wapas milta hai; khatam ho chuka ho to `trial_used` jawab aata hai, naya trial nahi banta.
- ⚠️ Ek had ab bhi hai: agar phone par internet hi na ho to app ka purana local 48h fallback chalta hai (ye malik ki purani "net na mile to lock na ho" wali policy ki wajah se rakha hai). Ise band karna ho to malik se pooch kar `_startTrial` ke catch wale hisse ko hata dein.

### 7. Version + Icon
- `pubspec.yaml`: **2.5.0+6** (app ke andar bhi har jagah v2.5.0 — purana 2.3.0/2.4.0 wala mix khatam).
- Launcher icon ab **asal Driving Care logo** hai: `android/app/src/main/res/mipmap-*/ic_launcher.png` + `ic_launcher_round.png` (logo file `saudia/driving_care_logo.jpg` se bane hain). Default Flutter icon khatam.

### 8. Dual-Mode Key Activation (Taza Tareen Update - 14 Oct 2026)
- **Masla jo solve hua:** Pehle code sirf `DCS-...` signed keys accept kar raha tha. Portal se banai gayi aam insani keys (maslan `DC-8891`, `BILAL-VIP`) phone par error deti theen ke "Purani plain keys band hain".
- **Naya Behtar Solution:** `main.dart` ab dono formats ko support karta hai:
  1. **Short Keys (`DC-8891`, `BILAL-VIP` waghera):** App seedha `$serverUrl/api/login.php` ko phone ki `ANDROID_ID` bhejti hai. Server database check karke key ko us phone ke sath **Hardware-Bind** kar deta hai aur license foran unlock ho jata hai. Agar wahi key kisi doosre phone par dali jaye to server reject karta hai: *"Ye key kisi aur phone par band hai."*
  2. **Offline DCS Keys:** Agar net na ho to `DCS-...` Ed25519 cryptographic signed key offline bhi bot ko activate kar sakti hai.
  3. **Zero Lockouts:** Ek baar phone par key activate ho jaye to cache mein save rehti hai; airplane mode ya net disconnect hone par bot kabhi band nahi hota.

## Jo NAHI badla (guardrails)
Package ID `com.drivingcare.saudi`, keystore/signing ka tareeqa, Ed25519 public key, device binding ka server flow, ping/heartbeat ki narmi (net girne par lock nahi), engine ki timings (600ms debounce waghera) — sab wesa ka wesa hai.

## Official Production Build & Sign (Verified Passed)
- **Flutter Build:** `flutter build apk --release` -> **Clean Success (22.3 MB)**
- **Code Health:** `flutter analyze` -> **0 errors, 0 warnings**
- **Apksigner Verification:**
  - `Verified using v1 scheme (JAR signing): true`
  - `Verified using v2 scheme (APK Signature Scheme v2): true`
  - `Certificate DN: CN=Driving Care, O=Driving Care KSA, L=Riyadh, C=SA`
- **Output Files:**
  - `cpanel_deploy/DrivingCare.apk` (22.3 MB)
  - `cpanel_deploy/Driving_Care_v2.5_Production.apk` (22.3 MB)
  - `cpanel_deploy_v2.5_ready.zip` (Complete web portal + API + APK for 1-click cPanel extract)

## Deploy (Server)
`cpanel_deploy_v2.5_ready.zip` ko cPanel File Manager mein `public_html/saudia` (ya site root) par extract kar dein. Tamam pages (`admin.html` with v2.5, `app.js`, `api/login.php`, `download.php`) foran update ho jayenge.

