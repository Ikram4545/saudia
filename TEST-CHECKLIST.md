# Driving Care v2.5.0 — Test Checklist (har line = saboot ke sath)

Device model + Android version pehle likhein: ______________________

Har test ke samne PASS/FAIL likhein. Ek bhi FAIL ho to wajah + screenshot lazmi hai.

## A. Fresh install
- [ ] Purani Driving Care pehle UNINSTALL ki, phir v2.5.0 fresh install ki.
- [ ] App ke andar version **v2.5.0** nazar aata hai.
- [ ] Launcher par icon **Driving Care ka asal logo** hai (Flutter wala default nahi).

## B. Permissions — guide se
- [ ] Accessibility ON karne par jahan atke, app ki guide ne khud step-by-step nikala (App Info → ⋮ → Allow restricted settings → ON).
- [ ] Battery Unrestricted, Overlay, Notifications — sab dashboard par asal (green) status dikhate hain.
- [ ] Dashboard par naya **"Jeeny Auto-Open" card** nazar aata hai.

## C. Jeeny Auto-Open (sab se ahem test)
- [ ] Auto-Open card se "Notification Access ON karein" daba kar list mein **"Driving Care Order Alerts"** ko Allow kiya — wapas aane par card ka status **ON ✔** ho gaya.
- [ ] Agar switch gray tha to guide ke steps se (Allow restricted settings) ON ho gaya.
- [ ] **Jeeny bilkul BAND kiya** (recent apps se bhi hata diya), phone ki home screen par aaye.
- [ ] Dusre phone se Jeeny par **asal order** bheja/aya.
- [ ] **Jeeny KHUD samne khul gaya** — kisi ne haath nahi lagaya.
- [ ] Order **khud accept** ho gaya.
- [ ] Auto-Open card par "Aakhri auto-open" ki line update hui.

## D. Floating button
- [ ] Jeeny ke upar chhota gol **DC button** nazar aata hai.
- [ ] Engine ON par button **sabz (green)** hai.
- [ ] Button par **tap** karne se engine OFF (button **laal**) ho gaya aur toast aya.
- [ ] Dobara tap par engine ON (sabz) ho gaya.
- [ ] Button ko **drag** karke dusri jaga le jaya gaya — wahi raha.
- [ ] App ke andar "Floating button" switch OFF karne par button gayab ho gaya; ON karne par wapas aya.

## E. Ek key = ek mobile
- [ ] Phone A par DCS key activate hui — app unlock ho gaya.
- [ ] **Wohi key Phone B par lagayi — reject hui** ("Ye key kisi aur phone par band hai" ya server ke device_mismatch wala jawab) aur Phone B unlock NAHI hua.
- [ ] Internet band karke (airplane mode) Phone A par app dobara khola — key chalti rahi, lock NAHI hua.
- [ ] Admin panel mein driver ke samne **Bound device** nazar ata hai; "Reset Device" ke baad Phone B par key chal gayi.

## F. Trial
- [ ] Naye phone par 48h trial shuru hua.
- [ ] App band karke dobara trial lene ki koshish — **dobara trial NAHI mila** (server ne mana kiya).

## G. Purani cheezein (regression)
- [ ] Jeeny pehle se khula ho to order auto-accept hota hai (purana flow).
- [ ] Price range / blocked locations ke rules pehle ki tarah kaam karte hain.
- [ ] 30 minute phone jeb mein rakha — koi order miss nahi, app background mein zinda raha.

## Lazmi saboot
- [ ] **Ek poori screen recording**: fresh install → permissions guide se ON → Jeeny band → order aya → Jeeny khud khula → floating button nazar aya → order khud accept. (Recording is file ke sath bhejein ya link yahan likhein: ______________________)
