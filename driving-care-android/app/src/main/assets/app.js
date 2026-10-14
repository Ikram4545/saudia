// Driving Care - Modern Mobile Application Engine
// Tailored for Saudi Arabia Drivers (Jeeny, Uber, Bolt)
// Partner: Ikram | Client: Bilal (+966 53 419 9549)

const VALID_LICENSE_KEYS = {
  'DC-8921': { validUntil: Date.now() + 28 * 24 * 60 * 60 * 1000, name: 'Tariq Al-Harbi (Riyadh)' },
  'DC-7740': { validUntil: Date.now() + 2 * 24 * 60 * 60 * 1000, name: 'Fahad Saeed (Jeddah)' },
  'asif30':  { validUntil: Date.now() + 25 * 24 * 60 * 60 * 1000, name: 'Muhammad Asif (Riyadh)' },
  'BILAL-VIP': { validUntil: Date.now() + 30 * 24 * 60 * 60 * 1000, name: 'Bilal VIP Admin Test' },
  'DC-2026': { validUntil: Date.now() + 30 * 24 * 60 * 60 * 1000, name: 'Standard Demo Driver' }
};

const I18N = {
  ar: {
    subtitle: 'بوت قبول الطلبات الذكي • السعودية 🇸🇦',
    licenseActive: 'مفعل (نشط)',
    licenseExpired: 'منتهي الصلاحية',
    daysLeft: 'يوم متبقي',
    licenseKey: 'مفتاح الترخيص:',
    clientContact: 'الدعم المعتمد:',
    activateBtn: 'تفعيل',
    botRunning: 'البوت يعمل الآن تلقائياً',
    botRunningSub: 'جاهز لصيد وتلقي الرحلات المناسبة فوراً',
    botStopped: 'البوت متوقف حالياً',
    botStoppedSub: 'اضغط على الزر لتفعيل القبول التلقائي',
    floatingHudTitle: 'زر الشاشة العائم (Floating HUD)',
    floatingHudDesc: 'أيقونة عائمة للتحكم أثناء فتح جيني أو أوبر',
    platformsTitle: 'التطبيقات المستهدفة',
    allActive: 'الكل مفعل',
    filtersTitle: 'معايير قبول الرحلات الذكية',
    smartFilter: 'فلترة متقدمة',
    minFare: 'الحد الأدنى للأجرة (Min Price):',
    maxFare: 'الحد الأقصى للأجرة (Max Price):',
    autoRejectTitle: 'رفض فوري للمشاوير الرخيصة',
    autoRejectDesc: 'تجاهل ورفض أي رحلة أقل من الحد الأدنى تلقائياً',
    pickupTime: 'أقصى وقت للوصول للزبون (ETA):',
    paymentMethods: 'طريقة الدفع المقبولة:',
    payCash: '💵 نقدي (Cash)',
    payCard: '💳 شبكة / محفظة (Card)',
    blacklistTitle: 'قائمة المناطق المحظورة (Blocklist)',
    autoSkip: 'يتم الرفض فوراً',
    blacklistDesc: 'المناطق المحددة هنا لن يقبل البوت أي رحلة متجهة إليها أو صادرة منها:',
    addAreaBtn: 'إضافة +',
    liveRadarTitle: 'رادار المشاوير المباشر',
    soundAlert: '🔊 صوت التنبيه',
    kpiScanned: 'المشاوير المفحوصة',
    kpiAccepted: 'تم قبولها تلقائياً',
    kpiEarned: 'القيمة الإجمالية',
    waitingForRides: 'جاري مسح الرحلات القادمة في الرياض وجدة...',
    partnerBilal: 'إدارة ومبيعات المفاتيح: بلال',
    contactWhatsApp: 'تواصل عبر الواتساب',
    acceptedStatus: 'تم القبول ✔',
    rejectedStatus: 'تم الرفض ✕',
    keySuccess: 'تم تفعيل المفتاح بنجاح! الصلاحية نشطة لـ 30 يوماً.',
    keyInvalid: 'مفتاح غير صالح! يرجى التواصل مع بلال للحصول على كود جديد.'
  },
  en: {
    subtitle: 'Smart Auto-Accept Bot • Saudi Arabia 🇸🇦',
    licenseActive: 'Active (Verified)',
    licenseExpired: 'License Expired',
    daysLeft: 'Days Left',
    licenseKey: 'License Key:',
    clientContact: 'Official Support:',
    activateBtn: 'Activate',
    botRunning: 'Bot Active & Scanning',
    botRunningSub: 'Auto-accepting high paying rides instantly',
    botStopped: 'Bot Paused / Offline',
    botStoppedSub: 'Tap circle button to start auto-accept engine',
    floatingHudTitle: 'Floating Screen HUD',
    floatingHudDesc: 'Overlay button to control bot while using Jeeny or Uber',
    platformsTitle: 'Target Platforms',
    allActive: 'All Active',
    filtersTitle: 'Smart Ride Acceptance Engine',
    smartFilter: 'Advanced Filters',
    minFare: 'Minimum Fare (Min Price):',
    maxFare: 'Maximum Fare (Max Price):',
    autoRejectTitle: 'Auto-Reject Cheap Fares',
    autoRejectDesc: 'Instantly dismiss rides below minimum fare threshold',
    pickupTime: 'Max Pickup Arrival ETA:',
    paymentMethods: 'Accepted Payment Methods:',
    payCash: '💵 Cash Rides',
    payCard: '💳 Card / Digital',
    blacklistTitle: 'Restricted Areas (Blocklist)',
    autoSkip: 'Auto Rejected',
    blacklistDesc: 'The bot will strictly avoid rides starting from or going to these areas:',
    addAreaBtn: 'Add +',
    liveRadarTitle: 'Live Ride Radar',
    soundAlert: '🔊 Audio Ping',
    kpiScanned: 'Rides Evaluated',
    kpiAccepted: 'Auto Accepted',
    kpiEarned: 'Total SAR',
    waitingForRides: 'Scanning rides in Riyadh, Jeddah & Dammam...',
    partnerBilal: 'License Sales & Admin: Bilal',
    contactWhatsApp: 'Contact on WhatsApp',
    acceptedStatus: 'ACCEPTED ✔',
    rejectedStatus: 'REJECTED ✕',
    keySuccess: 'Key verified! 30-day subscription active.',
    keyInvalid: 'Invalid key! Contact Bilal (+966 53 419 9549) to get a new license.'
  }
};

const SAUDI_SAMPLE_ROUTES = [
  { from: 'Al Olaya (العليا)', to: 'King Fahd Rd (طريق الملك فهد)', city: 'Riyadh', baseFare: 38, baseEta: 6, plat: 'jeeny' },
  { from: 'Al Nakheel (النخيل)', to: 'Riyadh Front (واجهة الرياض)', city: 'Riyadh', baseFare: 55, baseEta: 7, plat: 'uber' },
  { from: 'Al Malaz (الملز)', to: 'Al Murabba (المربع)', city: 'Riyadh', baseFare: 24, baseEta: 5, plat: 'jeeny' },
  { from: 'Al Batha (البطحاء)', to: 'Al Shamisi (الشميسي)', city: 'Riyadh', baseFare: 11, baseEta: 12, plat: 'jeeny', blacklisted: true },
  { from: 'Airport (مطار الملك خالد)', to: 'Al Yasmin (الياسمين)', city: 'Riyadh', baseFare: 85, baseEta: 14, plat: 'uber', blacklisted: true },
  { from: 'Corniche (الكورنيش)', to: 'Al Balad (البلد)', city: 'Jeddah', baseFare: 42, baseEta: 8, plat: 'bolt' },
  { from: 'Al Rawdah (الروضة)', to: 'Mall of Arabia (مجمع العرب)', city: 'Jeddah', baseFare: 49, baseEta: 6, plat: 'uber' },
  { from: 'Al Manfuha (منفوحة)', to: 'Al Batha (البطحاء)', city: 'Riyadh', baseFare: 12, baseEta: 10, plat: 'jeeny', blacklisted: true },
  { from: 'Al Faisaliyah (الفيصلية)', to: 'KAFD (المركز المالي)', city: 'Riyadh', baseFare: 65, baseEta: 5, plat: 'uber' },
  { from: 'Al Shatea (الشاطئ)', to: 'Al Hamra (الحمراء)', city: 'Jeddah', baseFare: 33, baseEta: 7, plat: 'bolt' }
];

class DrivingCareApp {
  constructor() {
    this.lang = 'ar';
    this.botRunning = true;
    this.audioCtx = null;
    this.simulationTimer = null;
    
    // Stats
    this.stats = {
      scanned: 0,
      accepted: 0,
      earned: 0
    };

    // State
    this.state = {
      minFare: 15,
      maxFare: 120,
      maxEta: 8,
      autoReject: true,
      soundEnabled: true,
      payCash: true,
      payCard: true,
      activeKey: 'DC-8921',
      platforms: { jeeny: true, uber: true, bolt: true },
      blacklist: ['Al Batha', 'Airport', 'Shamisi', 'Manfuha', 'Industrial']
    };

    this.init();
  }

  init() {
    this.loadState();
    this.bindDomElements();
    this.applyLanguage(this.lang);
    this.setupEventListeners();
    this.setupDraggableHUD();
    this.updateLicenseDisplay();
    this.startRadarSimulation();
    this.registerServiceWorker();
  }

  loadState() {
    try {
      const saved = localStorage.getItem('dc_bot_state');
      if (saved) {
        this.state = { ...this.state, ...JSON.parse(saved) };
      }
    } catch (e) {
      console.warn('Could not read state from localStorage', e);
    }
  }

  saveState() {
    try {
      localStorage.setItem('dc_bot_state', JSON.stringify(this.state));
    } catch (e) {
      console.warn('Could not save state', e);
    }
  }

  bindDomElements() {
    this.langToggleBtn = document.getElementById('langToggleBtn');
    this.langLabel = document.getElementById('langLabel');
    this.masterBotToggle = document.getElementById('masterBotToggle');
    this.botStateTitle = document.getElementById('botStateTitle');
    this.botStateSubtitle = document.getElementById('botStateSubtitle');
    this.floatingHudSwitch = document.getElementById('floatingHudSwitch');
    this.floatingHudWidget = document.getElementById('floatingHudWidget');
    this.hudToggleBtn = document.getElementById('hudToggleBtn');
    this.hudLiveTag = document.getElementById('hudLiveTag');
    this.hudStatus = document.getElementById('hudStatus');
    this.hudCloseBtn = document.getElementById('hudCloseBtn');

    // Filters
    this.minFareSlider = document.getElementById('minFareSlider');
    this.minFareValue = document.getElementById('minFareValue');
    this.maxFareSlider = document.getElementById('maxFareSlider');
    this.maxFareValue = document.getElementById('maxFareValue');
    this.pickupTimeSlider = document.getElementById('pickupTimeSlider');
    this.pickupTimeValue = document.getElementById('pickupTimeValue');
    this.autoRejectSwitch = document.getElementById('autoRejectSwitch');
    this.soundSwitch = document.getElementById('soundSwitch');

    // Payments
    this.payCash = document.getElementById('payCash');
    this.payCard = document.getElementById('payCard');

    // Blacklist
    this.blacklistChipsContainer = document.getElementById('blacklistChipsContainer');
    this.newAreaInput = document.getElementById('newAreaInput');
    this.addAreaBtn = document.getElementById('addAreaBtn');

    // KPI & Radar
    this.kpiScanned = document.getElementById('kpiScanned');
    this.kpiAccepted = document.getElementById('kpiAccepted');
    this.kpiEarned = document.getElementById('kpiEarned');
    this.radarFeedList = document.getElementById('radarFeedList');

    // License
    this.licenseBadge = document.getElementById('licenseBadge');
    this.licenseStatusText = document.getElementById('licenseStatusText');
    this.daysRemainingText = document.getElementById('daysRemainingText');
    this.currentLicenseKey = document.getElementById('currentLicenseKey');
    this.newLicenseKeyInput = document.getElementById('newLicenseKeyInput');
    this.activateKeyBtn = document.getElementById('activateKeyBtn');
    this.licenseAlert = document.getElementById('licenseAlert');

    // Sync input values with state
    this.minFareSlider.value = this.state.minFare;
    this.minFareValue.textContent = `${this.state.minFare} SAR`;
    this.maxFareSlider.value = this.state.maxFare;
    this.maxFareValue.textContent = `${this.state.maxFare} SAR`;
    this.pickupTimeSlider.value = this.state.maxEta;
    this.pickupTimeValue.textContent = `${this.state.maxEta} ${this.lang === 'ar' ? 'دقيقة' : 'min'}`;
    this.autoRejectSwitch.checked = this.state.autoReject;
    this.soundSwitch.checked = this.state.soundEnabled;
    this.payCash.checked = this.state.payCash;
    this.payCard.checked = this.state.payCard;
  }

  setupEventListeners() {
    // Language toggle
    this.langToggleBtn.addEventListener('click', () => {
      this.lang = this.lang === 'ar' ? 'en' : 'ar';
      this.applyLanguage(this.lang);
    });

    // Master power toggle
    this.masterBotToggle.addEventListener('click', () => this.toggleBot());
    this.hudToggleBtn.addEventListener('click', () => this.toggleBot());

    // Floating HUD Visibility
    this.floatingHudSwitch.addEventListener('change', (e) => {
      if (e.target.checked) {
        this.floatingHudWidget.classList.remove('hidden');
      } else {
        this.floatingHudWidget.classList.add('hidden');
      }
    });

    this.hudCloseBtn.addEventListener('click', () => {
      this.floatingHudWidget.classList.add('hidden');
      this.floatingHudSwitch.checked = false;
    });

    // Sliders
    this.minFareSlider.addEventListener('input', (e) => {
      this.state.minFare = parseInt(e.target.value, 10);
      this.minFareValue.textContent = `${this.state.minFare} SAR`;
      if (this.state.minFare > this.state.maxFare) {
        this.state.maxFare = this.state.minFare + 10;
        this.maxFareSlider.value = this.state.maxFare;
        this.maxFareValue.textContent = `${this.state.maxFare} SAR`;
      }
      this.saveState();
    });

    this.maxFareSlider.addEventListener('input', (e) => {
      this.state.maxFare = parseInt(e.target.value, 10);
      this.maxFareValue.textContent = `${this.state.maxFare} SAR`;
      this.saveState();
    });

    this.pickupTimeSlider.addEventListener('input', (e) => {
      this.state.maxEta = parseInt(e.target.value, 10);
      this.pickupTimeValue.textContent = `${this.state.maxEta} ${this.lang === 'ar' ? 'دقيقة' : 'min'}`;
      this.saveState();
    });

    this.autoRejectSwitch.addEventListener('change', (e) => {
      this.state.autoReject = e.target.checked;
      this.saveState();
    });

    this.soundSwitch.addEventListener('change', (e) => {
      this.state.soundEnabled = e.target.checked;
      this.saveState();
    });

    // Payment toggles
    this.payCash.addEventListener('change', (e) => {
      this.state.payCash = e.target.checked;
      e.target.closest('.pill-check').classList.toggle('active', e.target.checked);
      this.saveState();
    });

    this.payCard.addEventListener('change', (e) => {
      this.state.payCard = e.target.checked;
      e.target.closest('.pill-check').classList.toggle('active', e.target.checked);
      this.saveState();
    });

    // Platforms
    document.querySelectorAll('.platform-item').forEach(item => {
      const plat = item.dataset.platform;
      const chk = item.querySelector('input');
      chk.addEventListener('change', (e) => {
        this.state.platforms[plat] = e.target.checked;
        item.classList.toggle('active', e.target.checked);
        this.saveState();
      });
    });

    // Add blacklist item
    this.addAreaBtn.addEventListener('click', () => this.addBlacklistArea());
    this.newAreaInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') this.addBlacklistArea();
    });

    // Remove blacklist items
    this.blacklistChipsContainer.addEventListener('click', (e) => {
      if (e.target.classList.contains('chip-remove')) {
        const chip = e.target.closest('.chip');
        const loc = chip.dataset.loc;
        this.state.blacklist = this.state.blacklist.filter(x => x !== loc);
        chip.remove();
        this.saveState();
      }
    });

    // License activation
    this.activateKeyBtn.addEventListener('click', () => this.activateKey());
    this.newLicenseKeyInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') this.activateKey();
    });
  }

  toggleBot() {
    this.botRunning = !this.botRunning;
    this.playAudioAlert(this.botRunning ? 880 : 330);

    if (this.botRunning) {
      this.masterBotToggle.classList.remove('inactive');
      this.masterBotToggle.classList.add('active');
      this.hudToggleBtn.classList.remove('inactive');
      this.hudLiveTag.textContent = 'ON';
      this.hudLiveTag.style.background = '#10b981';
      this.hudStatus.textContent = this.lang === 'ar' ? 'قبول تلقائي: نشط' : 'Auto Accept: ON';
      this.botStateTitle.textContent = I18N[this.lang].botRunning;
      this.botStateSubtitle.textContent = I18N[this.lang].botRunningSub;
    } else {
      this.masterBotToggle.classList.add('inactive');
      this.masterBotToggle.classList.remove('active');
      this.hudToggleBtn.classList.add('inactive');
      this.hudLiveTag.textContent = 'OFF';
      this.hudLiveTag.style.background = '#ef4444';
      this.hudStatus.textContent = this.lang === 'ar' ? 'البوت متوقف' : 'Bot Paused';
      this.botStateTitle.textContent = I18N[this.lang].botStopped;
      this.botStateSubtitle.textContent = I18N[this.lang].botStoppedSub;
    }
  }

  addBlacklistArea() {
    const val = this.newAreaInput.value.trim();
    if (!val) return;
    if (!this.state.blacklist.includes(val)) {
      this.state.blacklist.push(val);
      const span = document.createElement('span');
      span.className = 'chip';
      span.dataset.loc = val;
      span.innerHTML = `${val} <button class="chip-remove">&times;</button>`;
      this.blacklistChipsContainer.appendChild(span);
      this.saveState();
    }
    this.newAreaInput.value = '';
  }

  activateKey() {
    const inputVal = this.newLicenseKeyInput.value.trim().toUpperCase();
    if (!inputVal) return;

    if (VALID_LICENSE_KEYS[inputVal]) {
      this.state.activeKey = inputVal;
      this.saveState();
      this.updateLicenseDisplay();
      this.showLicenseAlert(I18N[this.lang].keySuccess, 'success');
      this.playAudioAlert(1046); // High C sound
    } else {
      this.showLicenseAlert(I18N[this.lang].keyInvalid, 'error');
      this.playAudioAlert(220); // Low sound
    }
    this.newLicenseKeyInput.value = '';
  }

  updateLicenseDisplay() {
    const keyData = VALID_LICENSE_KEYS[this.state.activeKey];
    if (keyData) {
      const msLeft = keyData.validUntil - Date.now();
      const daysLeft = Math.max(0, Math.ceil(msLeft / (1000 * 60 * 60 * 24)));
      this.currentLicenseKey.textContent = this.state.activeKey;
      this.daysRemainingText.innerHTML = `${daysLeft} <span>${I18N[this.lang].daysLeft}</span>`;
      this.licenseBadge.className = 'license-status-badge active';
      this.licenseStatusText.textContent = I18N[this.lang].licenseActive;
    } else {
      this.currentLicenseKey.textContent = this.state.activeKey || 'NONE';
      this.daysRemainingText.innerHTML = `0 <span>${I18N[this.lang].daysLeft}</span>`;
      this.licenseBadge.className = 'license-status-badge expired';
      this.licenseStatusText.textContent = I18N[this.lang].licenseExpired;
    }
  }

  showLicenseAlert(msg, type) {
    this.licenseAlert.textContent = msg;
    this.licenseAlert.className = `license-alert ${type}`;
    setTimeout(() => {
      this.licenseAlert.className = 'license-alert hidden';
    }, 4500);
  }

  applyLanguage(lang) {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    this.langLabel.textContent = lang === 'ar' ? 'English' : 'العربية';

    // Update all i18n data elements
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.dataset.i18n;
      if (I18N[lang][key]) {
        el.textContent = I18N[lang][key];
      }
    });

    // Update sliders and status text
    this.minFareValue.textContent = `${this.state.minFare} SAR`;
    this.maxFareValue.textContent = `${this.state.maxFare} SAR`;
    this.pickupTimeValue.textContent = `${this.state.maxEta} ${lang === 'ar' ? 'دقيقة' : 'min'}`;

    if (this.botRunning) {
      this.botStateTitle.textContent = I18N[lang].botRunning;
      this.botStateSubtitle.textContent = I18N[lang].botRunningSub;
      this.hudStatus.textContent = lang === 'ar' ? 'قبول تلقائي: نشط' : 'Auto Accept: ON';
    } else {
      this.botStateTitle.textContent = I18N[lang].botStopped;
      this.botStateSubtitle.textContent = I18N[lang].botStoppedSub;
      this.hudStatus.textContent = lang === 'ar' ? 'البوت متوقف' : 'Bot Paused';
    }

    this.updateLicenseDisplay();
  }

  playAudioAlert(freq = 880) {
    if (!this.state.soundEnabled) return;
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!this.audioCtx) this.audioCtx = new AudioCtx();
      if (this.audioCtx.state === 'suspended') {
        this.audioCtx.resume();
      }

      const osc = this.audioCtx.createOscillator();
      const gain = this.audioCtx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, this.audioCtx.currentTime);
      // Nice futuristic slide up
      osc.frequency.exponentialRampToValueAtTime(freq * 1.5, this.audioCtx.currentTime + 0.15);

      gain.gain.setValueAtTime(0.18, this.audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, this.audioCtx.currentTime + 0.22);

      osc.connect(gain);
      gain.connect(this.audioCtx.destination);

      osc.start();
      osc.stop(this.audioCtx.currentTime + 0.22);
    } catch (e) {
      // AudioContext might be blocked until user gesture
    }
  }

  startRadarSimulation() {
    // Generate simulated incoming rides periodically
    this.simulationTimer = setInterval(() => {
      if (!this.botRunning) return;
      this.simulateIncomingRide();
    }, 4500);
  }

  simulateIncomingRide() {
    const route = SAUDI_SAMPLE_ROUTES[Math.floor(Math.random() * SAUDI_SAMPLE_ROUTES.length)];
    const priceVariance = Math.floor(Math.random() * 18) - 6;
    const fare = Math.max(10, route.baseFare + priceVariance);
    const eta = Math.max(3, route.baseEta + Math.floor(Math.random() * 4) - 1);
    const isCash = Math.random() > 0.45;
    const plat = route.plat;

    // Check platform
    if (!this.state.platforms[plat]) return;

    this.stats.scanned++;
    this.kpiScanned.textContent = this.stats.scanned;

    // Evaluation Logic
    let isAccepted = true;
    let reason = '';

    // Check fare
    if (fare < this.state.minFare) {
      isAccepted = false;
      reason = `${fare} SAR < Min ${this.state.minFare} SAR`;
    } else if (fare > this.state.maxFare) {
      isAccepted = false;
      reason = `${fare} SAR > Max ${this.state.maxFare} SAR`;
    }

    // Check ETA
    if (isAccepted && eta > this.state.maxEta) {
      isAccepted = false;
      reason = `ETA ${eta}m > Max ${this.state.maxEta}m`;
    }

    // Check payment mode
    if (isAccepted) {
      if (isCash && !this.state.payCash) {
        isAccepted = false;
        reason = 'Cash Disabled';
      } else if (!isCash && !this.state.payCard) {
        isAccepted = false;
        reason = 'Card Disabled';
      }
    }

    // Check blacklist
    if (isAccepted) {
      for (const blocked of this.state.blacklist) {
        if (route.from.toLowerCase().includes(blocked.toLowerCase()) || 
            route.to.toLowerCase().includes(blocked.toLowerCase())) {
          isAccepted = false;
          reason = `Blocked Area: ${blocked}`;
          break;
        }
      }
    }

    if (isAccepted) {
      this.stats.accepted++;
      this.stats.earned += fare;
      this.kpiAccepted.textContent = this.stats.accepted;
      this.kpiEarned.textContent = `${this.stats.earned} SAR`;
      this.playAudioAlert(920);
      document.getElementById('hudLastRide').textContent = `Accepted ${fare} SAR • ${route.city}`;
    }

    this.appendRadarEvent({
      plat: plat.toUpperCase(),
      from: route.from,
      to: route.to,
      city: route.city,
      fare,
      eta,
      isCash,
      isAccepted,
      reason
    });
  }

  appendRadarEvent(event) {
    const placeholder = this.radarFeedList.querySelector('.empty-feed-placeholder');
    if (placeholder) placeholder.remove();

    const item = document.createElement('div');
    item.className = `ride-item ${event.isAccepted ? 'accepted' : 'rejected'}`;
    
    const statusText = event.isAccepted ? I18N[this.lang].acceptedStatus : `${I18N[this.lang].rejectedStatus} (${event.reason})`;
    const paymentIcon = event.isCash ? '💵 Cash' : '💳 Card';

    item.innerHTML = `
      <div class="ride-details">
        <div class="ride-platform-row">
          <strong>${event.plat}</strong> &bull; <span>${event.city}</span> &bull; <span>${paymentIcon}</span> &bull; <span>⏱ ${event.eta} min</span>
        </div>
        <div class="ride-route">${event.from} &rarr; ${event.to}</div>
        <div class="ride-meta">${event.isAccepted ? 'Auto-Accepted by Driving Care' : event.reason}</div>
      </div>
      <div class="ride-action-box">
        <div class="ride-fare">${event.fare} SAR</div>
        <span class="ride-status-tag ${event.isAccepted ? 'accepted' : 'rejected'}">${statusText}</span>
      </div>
    `;

    this.radarFeedList.insertBefore(item, this.radarFeedList.firstChild);

    // Keep max 15 events in feed
    while (this.radarFeedList.children.length > 15) {
      this.radarFeedList.removeChild(this.radarFeedList.lastChild);
    }
  }

  setupDraggableHUD() {
    const hud = this.floatingHudWidget;
    let isDragging = false;
    let startX, startY, origX, origY;

    const onStart = (e) => {
      if (e.target.closest('button')) return; // Allow button clicks
      isDragging = true;
      const clientX = e.clientX || (e.touches && e.touches[0].clientX);
      const clientY = e.clientY || (e.touches && e.touches[0].clientY);
      startX = clientX;
      startY = clientY;
      const rect = hud.getBoundingClientRect();
      origX = rect.left;
      origY = rect.top;
    };

    const onMove = (e) => {
      if (!isDragging) return;
      const clientX = e.clientX || (e.touches && e.touches[0].clientX);
      const clientY = e.clientY || (e.touches && e.touches[0].clientY);
      const dx = clientX - startX;
      const dy = clientY - startY;
      hud.style.left = `${Math.max(10, Math.min(window.innerWidth - 180, origX + dx))}px`;
      hud.style.top = `${Math.max(10, Math.min(window.innerHeight - 80, origY + dy))}px`;
    };

    const onEnd = () => {
      isDragging = false;
    };

    hud.addEventListener('mousedown', onStart);
    hud.addEventListener('touchstart', onStart, { passive: true });
    window.addEventListener('mousemove', onMove);
    window.addEventListener('touchmove', onMove, { passive: true });
    window.addEventListener('mouseup', onEnd);
    window.addEventListener('touchend', onEnd);
  }

  registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('./sw.js')
        .then(() => console.log('Driving Care ServiceWorker Active'))
        .catch(err => console.log('SW registration error:', err));
    }
  }
}

// Launch app when DOM is ready
window.addEventListener('DOMContentLoaded', () => {
  window.drivingCare = new DrivingCareApp();
});
