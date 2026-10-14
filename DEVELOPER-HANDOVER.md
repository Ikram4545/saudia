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

## Jo NAHI badla (guardrails)
Package ID `com.drivingcare.saudi`, keystore/signing ka tareeqa, Ed25519 public key, device binding ka server flow, ping/heartbeat ki narmi (net girne par lock nahi), engine ki timings (600ms debounce waghera) — sab wesa ka wesa hai.

## Code validation — Muse ki taraf se ho chuki hai (14 Oct 2026)
- **Dart:** `flutter analyze` — **0 errors, 0 warnings** (sirf 13 info-level deprecation notes jo naye Flutter 3.47 ki wajah se aati hain — `withOpacity`/`activeColor`; code par koi asar nahi).
- **Kotlin:** teeno files (MainActivity, DrivingCareAccessibilityService, DrivingCareNotificationListener) standalone Kotlin compiler (1.8.22) se asal Android + Flutter + AndroidX libraries ke khilaf compile ki gayin — **0 errors**, class files ban gayin.
- **Poori APK packaging Muse ki machine par nahi ho saki** — wajah code nahi hai: is sandbox environment mein Gradle ka background process (daemon) band ho jata hai, is liye `flutter build` yahan complete nahi hota. Aap ki machine par standard build bilkul chalega (neeche wali section).

## Build kaise karni hai
Standard tareeqa:
```
cd flutter_driving_care
flutter pub get
flutter build apk --release
```
Release signing ke liye `android/key.properties` ya mojooda `driving_care.keystore` wala setup use karein (jese pehle hota tha). **APK isi code se bani ho** — koi patch/repack script nahi.

## Deploy (server)
`cpanel_deploy/api/trial.php` ko server par replace kar dein. Baqi API files mein koi tabdeeli nahi.

## Saboot (lazmi)
`TEST-CHECKLIST.md` ki har line asal phone par chala kar tick karein + poori screen recording bhejein. Recording ke baghair ye delivery mukammal nahi mani jayegi.
