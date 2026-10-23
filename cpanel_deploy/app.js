// Driving Care Portal - Core Application Logic
// Designed for Bilal (Owner) & Ikram (Technical Partner - 15% Share)

const STORAGE_KEY = 'driving_care_drivers_v1';
const SAR_TO_PKR_RATE = 74.5; // Approximate exchange rate

// Pre-seeded sample drivers for demonstration
const DEFAULT_DRIVERS = [
  {
    id: 'd1',
    sellerName: 'Client KSA',
    name: 'Tariq Al-Harbi',
    phone: '+966 50 491 8821',
    city: 'Riyadh',
    key: 'DC-8921',
    salePrice: 40,
    feeSAR: 40,
    commissionPercent: 30,
    myShare: 12.0,
    clientShare: 28.0,
    status: 'active',
    activatedAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: new Date(Date.now() + 25 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'd2',
    sellerName: 'Client KSA',
    name: 'Fahad Saeed',
    phone: '+966 55 128 9034',
    city: 'Jeddah',
    key: 'DC-7740',
    salePrice: 50,
    feeSAR: 50,
    commissionPercent: 40,
    myShare: 20.0,
    clientShare: 30.0,
    status: 'active',
    activatedAt: new Date(Date.now() - 28 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'd3',
    sellerName: 'Bilal Reseller',
    name: 'Muhammad Asif',
    phone: '+966 53 874 1120',
    city: 'Riyadh',
    key: 'asif30',
    salePrice: 30,
    feeSAR: 30,
    commissionPercent: 30,
    myShare: 9.0,
    clientShare: 21.0,
    status: 'expired',
    activatedAt: new Date(Date.now() - 35 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
  }
];

class DrivingCarePortal {
  constructor() {
    this.adminToken = localStorage.getItem('dc_admin_token');
    this.drivers = this.loadDrivers();
    this.activeFilter = 'all';
    this.searchQuery = '';
    this.initElements();
    this.bindEvents();
    this.initAuth();
    this.render();
    if (this.adminToken) {
      this.startLivePolling();
    }
  }

  loadDrivers() {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch (e) {
        console.error('Failed to parse drivers storage', e);
      }
    }
    this.saveDrivers(DEFAULT_DRIVERS);
    return DEFAULT_DRIVERS;
  }

  saveDrivers(data) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  }


  // Admin Authentication Gate Management
  initAuth() {
    // Password toggle
    if (this.toggleAdminPwBtn && this.adminPasswordInput) {
      this.toggleAdminPwBtn.addEventListener('click', () => {
        const isPw = this.adminPasswordInput.type === 'password';
        this.adminPasswordInput.type = isPw ? 'text' : 'password';
        this.toggleAdminPwBtn.textContent = isPw ? '🔒' : '👁️';
      });
    }

    // Check existing session
    if (!this.adminToken) {
      if (this.adminLoginModal) this.adminLoginModal.style.display = 'flex';
    } else {
      if (this.adminLoginModal) this.adminLoginModal.style.display = 'none';
    }

    // Login Form Submit
    if (this.adminLoginForm) {
      this.adminLoginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = this.adminUsernameInput.value.trim();
        const password = this.adminPasswordInput.value.trim();
        if (this.loginErrorAlert) this.loginErrorAlert.style.display = 'none';

        try {
          const res = await fetch('/api/admin/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
          });
          const data = await res.json();
          if (res.ok && data.success) {
            this.adminToken = data.token;
            localStorage.setItem('dc_admin_token', data.token);
            localStorage.setItem('dc_admin_user', data.username || username);
            if (this.adminLoginModal) this.adminLoginModal.style.display = 'none';
            this.showToast(`Khush amdeed ${data.username || username}! Admin Portal Unlocked.`);
            this.startLivePolling();
          } else {
            if (this.loginErrorAlert) {
              this.loginErrorAlert.textContent = data.message || 'Ghalat password! Baraye meherbani sahi password darj karein.';
              this.loginErrorAlert.style.display = 'block';
            }
          }
        } catch (err) {
          // Fallback check
          if (false) {
            const fakeToken = 'offline_token_' + Date.now();
            this.adminToken = fakeToken;
            localStorage.setItem('dc_admin_token', fakeToken);
            if (this.adminLoginModal) this.adminLoginModal.style.display = 'none';
            this.showToast('Admin Panel Unlocked (Master Override)');
            this.render();
            this.startLivePolling();
          } else {
            if (this.loginErrorAlert) {
              this.loginErrorAlert.textContent = 'Ghalat password! Please enter correct password.';
              this.loginErrorAlert.style.display = 'block';
            }
          }
        }
      });
    }

    // Logout Button
    if (this.adminLogoutBtn) {
      this.adminLogoutBtn.addEventListener('click', () => {
        if (confirm('Admin panel ko lock aur logout karna chahte hain?')) {
          localStorage.removeItem('dc_admin_token');
          this.adminToken = null;
          if (this.adminLoginModal) this.adminLoginModal.style.display = 'flex';
          if (this.adminPasswordInput) this.adminPasswordInput.value = '';
          this.showToast('Admin panel locked.');
        }
      });
    }
  }

  initElements() {
    // Stats
    this.totalDriversCount = document.getElementById('totalDriversCount');
    this.activeLicensesCount = document.getElementById('activeLicensesCount');
    this.expiredLicensesCount = document.getElementById('expiredLicensesCount');
    this.totalRevenueSAR = document.getElementById('totalRevenueSAR');
    this.ikramShareText = document.getElementById('ikramShareText');

    // Counts
    this.countAll = document.getElementById('countAll');
    this.countActive = document.getElementById('countActive');
    this.countExpiring = document.getElementById('countExpiring');
    this.countExpired = document.getElementById('countExpired');
    this.countPending = document.getElementById('countPending');

    // Table & Empty State
    this.driversTableBody = document.getElementById('driversTableBody');
    this.emptyState = document.getElementById('emptyState');

    // Filter controls
    this.tabButtons = document.querySelectorAll('.tab-btn');
    this.searchInput = document.getElementById('searchInput');

    // Add Driver Modal
    this.addDriverBtn = document.getElementById('addDriverBtn');
    this.driverModal = document.getElementById('driverModal');
    this.closeModalBtn = document.getElementById('closeModalBtn');
    this.cancelDriverBtn = document.getElementById('cancelDriverBtn');
    this.driverForm = document.getElementById('driverForm');
    this.driverNameInput = document.getElementById('driverName');
    this.driverPhoneInput = document.getElementById('driverPhone');
    this.driverCityInput = document.getElementById('driverCity');
    this.driverKeyInput = document.getElementById('driverKey');
    this.driverSellerInput = document.getElementById('driverSeller');
    this.driverSalePriceInput = document.getElementById('driverSalePrice');
    this.driverFeeInput = document.getElementById('driverFee') || this.driverSalePriceInput;
    this.calcPreviewBox = document.getElementById('calcPreviewBox');
    this.clientShareText = document.getElementById('clientShareText');
    this.regenerateKeyBtn = document.getElementById('regenerateKeyBtn');

    // Simulator Modal
    this.openSimulatorBtn = document.getElementById('openSimulatorBtn');
    this.simulatorModal = document.getElementById('simulatorModal');
    this.closeSimulatorBtn = document.getElementById('closeSimulatorBtn');
    this.simKeyInput = document.getElementById('simKeyInput');
    this.simVerifyBtn = document.getElementById('simVerifyBtn');
    this.simStatusBanner = document.getElementById('simStatusBanner');
    this.simVerificationResult = document.getElementById('simVerificationResult');

    // Backup
    this.exportDataBtn = document.getElementById('exportDataBtn');
    this.toastContainer = document.getElementById('toastContainer');
  }

  bindEvents() {
    // Filter tabs
    this.tabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        this.tabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.activeFilter = btn.dataset.filter;
        this.renderTable();
      });
    });

    // Search input
    this.searchInput.addEventListener('input', (e) => {
      this.searchQuery = e.target.value.toLowerCase().trim();
      this.renderTable();
    });

    // Add Driver Modal Open/Close
    this.addDriverBtn.addEventListener('click', () => this.openAddModal());
    this.closeModalBtn.addEventListener('click', () => this.closeAddModal());
    this.cancelDriverBtn.addEventListener('click', () => this.closeAddModal());
    this.regenerateKeyBtn.addEventListener('click', () => this.generateRandomKey());

    // Submit Driver Form
    this.driverForm.addEventListener('submit', (e) => {
      e.preventDefault();
      this.handleSaveDriver();
    });

    // Simulator Modal
    this.openSimulatorBtn.addEventListener('click', () => {
      this.simulatorModal.style.display = 'flex';
    });
    this.closeSimulatorBtn.addEventListener('click', () => {
      this.simulatorModal.style.display = 'none';
    });
    this.simVerifyBtn.addEventListener('click', () => this.handleSimulateVerify());

    // Export Data
    this.exportDataBtn.addEventListener('click', () => this.exportBackup());
  }

  generateRandomKey() {
    const rand = Math.floor(1000 + Math.random() * 9000);
    this.driverKeyInput.value = `DC-${rand}`;
  }

  setPricePreset(price) {
    if (this.driverSalePriceInput) {
      this.driverSalePriceInput.value = price;
      this.updateProfitPreview();
    }
  }

  updateProfitPreview() {
    const price = parseFloat(this.driverSalePriceInput?.value) || 40;
    const commInput = document.querySelector('input[name="commissionPercent"]:checked');
    const comm = parseFloat(commInput ? commInput.value : 30);
    const myShare = (price * (comm / 100)).toFixed(1);
    const clientShare = (price - myShare).toFixed(1);
    if (this.calcPreviewBox) {
      this.calcPreviewBox.innerHTML = `Selling: <strong>${price} SAR</strong> ➔ <strong>My Share: ${myShare} SAR (${comm}%)</strong> | Client Share: <strong>${clientShare} SAR (${100 - comm}%)</strong>`;
    }
  }

  openAddModal() {
    this.driverForm.reset();
    this.generateRandomKey();
    if (this.driverSellerInput) this.driverSellerInput.value = 'Client KSA';
    if (this.driverSalePriceInput) this.driverSalePriceInput.value = '40';
    this.updateProfitPreview();
    this.driverModal.style.display = 'flex';
  }

  closeAddModal() {
    this.driverModal.style.display = 'none';
  }

  handleSaveDriver() {
    const sellerName = this.driverSellerInput ? (this.driverSellerInput.value.trim() || 'Client KSA') : 'Client KSA';
    const name = this.driverNameInput.value.trim();
    const phone = this.driverPhoneInput.value.trim();
    const city = this.driverCityInput.value;
    const key = this.driverKeyInput.value.trim();
    const salePrice = parseFloat(this.driverSalePriceInput ? this.driverSalePriceInput.value : (this.driverFeeInput ? this.driverFeeInput.value : 40)) || 40;
    const commInput = document.querySelector('input[name="commissionPercent"]:checked');
    const commissionPercent = parseFloat(commInput ? commInput.value : 30);
    const myShare = Math.round(salePrice * (commissionPercent / 100) * 10) / 10;
    const clientShare = Math.round((salePrice - myShare) * 10) / 10;
    const initialStatus = document.querySelector('input[name="initialStatus"]:checked').value;

    if (!name || !phone || !key) {
      this.showToast('Please fill all required fields', 'error');
      return;
    }

    // Check key duplicate
    const exists = this.drivers.find(d => d.key.toLowerCase() === key.toLowerCase());
    if (exists) {
      this.showToast('This License Key already exists! Please use a unique key.', 'error');
      return;
    }

    const now = new Date();
    let activatedAt = null;
    let expiresAt = null;

    if (initialStatus === 'active') {
      activatedAt = now.toISOString();
      const exp = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      expiresAt = exp.toISOString();
    }

    const newDriver = {
      id: 'd_' + Date.now(),
      sellerName,
      name,
      phone,
      city,
      key,
      salePrice,
      feeSAR: salePrice,
      commissionPercent,
      myShare,
      clientShare,
      status: initialStatus,
      activatedAt,
      expiresAt
    };

    this.drivers.unshift(newDriver);
    this.saveDrivers(this.drivers);
    this.closeAddModal();
    this.render();
    this.showToast(`Driver ${name} created with 30-day key: ${key}!`);

    // Always sync to backend and retrieve Ed25519 signed key
    fetch('/api/admin/create-key', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
      },
      body: JSON.stringify({ name, phone, city, key, days: 30, sellerName, salePrice, commissionPercent, myShare, clientShare })
    })
    .then(r => r.json())
    .then(data => {
      if (data && data.signedKey) {
        newDriver.signedKey = data.signedKey;
        this.saveDrivers(this.drivers);
        this.render();
      }
    })
    .catch(e => console.error('Failed to sync key to server:', e));
  }

  // Activate Pending Driver (Start 30-Day timer)
  activateDriver(id) {
    const driver = this.drivers.find(d => d.id === id);
    if (!driver) return;

    const now = new Date();
    driver.status = 'active';
    driver.activatedAt = now.toISOString();
    driver.expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString();

    this.saveDrivers(this.drivers);
    this.render();
    this.showToast(`Key for ${driver.name} activated for 30 Days!`);
  }

  // 1-Click Monthly Renewal (+30 Days)
  renewDriver(id) {
    const driver = this.drivers.find(d => d.id === id);
    if (!driver) return;

    const now = new Date();
    // If active and has remaining days, extend by 30 days; otherwise start 30 days from now
    let baseTime = now.getTime();
    if (driver.status === 'active' && driver.expiresAt && new Date(driver.expiresAt) > now) {
      baseTime = new Date(driver.expiresAt).getTime();
    }

    driver.status = 'active';
    driver.activatedAt = driver.activatedAt || now.toISOString();
    driver.expiresAt = new Date(baseTime + 30 * 24 * 60 * 60 * 1000).toISOString();

    this.saveDrivers(this.drivers);
    this.render();
    this.showToast(`Renewed! ${driver.name}'s key extended by 30 Days!`);
  }

  // Delete Driver
  deleteDriver(id) {
    const driver = this.drivers.find(d => d.id === id);
    if (!driver) return;
    if (confirm(`Are you sure you want to remove ${driver.name}?`)) {
      this.drivers = this.drivers.filter(d => d.id !== id);
      this.saveDrivers(this.drivers);
      this.render();
      this.showToast(`Driver ${driver.name} removed.`);

      if (driver.key) {
        fetch('/api/admin/delete-driver', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
          },
          body: JSON.stringify({ key: driver.key })
        }).catch(e => console.error('Failed to delete on server:', e));
      }
    }
  }

  // Generate WhatsApp Message for Driver
  copyDriverWhatsApp(id) {
    const d = this.drivers.find(x => x.id === id);
    if (!d) return;

    const expDateStr = d.expiresAt ? new Date(d.expiresAt).toLocaleDateString('en-GB') : 'Upon Activation';
    const activeKey = d.signedKey || d.key;
    const message = 
`Salam ${d.name} Bhai! 🚗
Aap ki "Driving Care" Auto Bot App ki key ready hai:

🔑 *License Key:* ${activeKey}
📅 *Validity:* 30 Days (Valid until: ${expDateStr})
⚡ *Supported Apps:* Jeeny, Uber, Bolt

*How to Activate:*
1. Driving Care app open karein.
2. Apna user key daalein: *${activeKey}*
3. "Activate App" par click karein.
4. Settings mein Min Price, Max Price aur Area select karke Bot ON kar lein!

Download APK: Driving Care Official APK (v2.5)
Support WhatsApp: Official Support (+966 53 419 9549)`;

    navigator.clipboard.writeText(message).then(() => {
      this.showToast(`WhatsApp message copied for ${d.name}!`);
    }).catch(() => {
      prompt('Copy this message for driver:', message);
    });
  }

  // FIX B: Reset Bound Device Phone for Driver Key
  async resetDeviceBinding(key) {
    if (!confirm(`Driver key ${key} ki Device Binding reset karni hai? Phone badalne ki ijazat mil jayegi.`)) return;
    try {
      const res = await fetch('/api/admin_reset_device.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (this.adminToken || localStorage.getItem('dc_admin_token') || ''),
          'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
        },
        body: JSON.stringify({ key })
      });
      const data = await res.json();
      if (data.success) {
        this.showToast(data.message || `Device binding reset for ${key}!`);
        const target = this.drivers.find(d => d.key === key);
        if (target) {
          target.boundDeviceId = null;
          this.saveDrivers(this.drivers);
        }
        this.render();
      } else {
        this.showToast(data.message || 'Error resetting device', 'error');
      }
    } catch (e) {
      this.showToast('Network error while resetting device', 'error');
    }
  }

  // Copy Key to Clipboard
  copyKey(key) {
    navigator.clipboard.writeText(key).then(() => {
      this.showToast(`Copied key: ${key}`);
    }).catch(() => {
      prompt('Copy key:', key);
    });
  }

  // Driver App Simulator Logic
  handleSimulateVerify() {
    const key = this.simKeyInput.value.trim();
    if (!key) {
      this.simVerificationResult.style.display = 'block';
      this.simVerificationResult.className = 'sim-result error';
      this.simVerificationResult.innerHTML = '❌ Please enter a user key.';
      return;
    }

    const found = this.drivers.find(d => d.key.toLowerCase() === key.toLowerCase());
    this.simVerificationResult.style.display = 'block';

    if (!found) {
      this.simStatusBanner.className = 'sim-badge inactive';
      this.simStatusBanner.textContent = 'ACCOUNT INACTIVE';
      this.simVerificationResult.className = 'sim-result error';
      this.simVerificationResult.innerHTML = `<strong>❌ Invalid Key!</strong><br>Contact Bilal to purchase a license.`;
      return;
    }

    if (found.status === 'pending') {
      this.simStatusBanner.className = 'sim-badge inactive';
      this.simStatusBanner.textContent = 'PAYMENT PENDING';
      this.simVerificationResult.className = 'sim-result warning';
      this.simVerificationResult.innerHTML = `<strong>⏳ Key Pending Activation</strong><br>Driver: ${found.name}<br>Waiting for Bilal's confirmation.`;
      return;
    }

    // Check expiry
    const now = new Date();
    const exp = new Date(found.expiresAt);

    if (exp <= now || found.status === 'expired') {
      this.simStatusBanner.className = 'sim-badge inactive';
      this.simStatusBanner.textContent = 'EXPIRED';
      this.simVerificationResult.className = 'sim-result error';
      this.simVerificationResult.innerHTML = `<strong>⚠️ 30-Day License Expired!</strong><br>Expired on ${exp.toLocaleDateString()}<br>Contact Bilal to renew.`;
      return;
    }

    // Success Active
    this.simStatusBanner.className = 'sim-badge active';
    this.simStatusBanner.textContent = 'ACCOUNT ACTIVE';
    this.simVerificationResult.className = 'sim-result';
    this.simVerificationResult.innerHTML = 
      `<strong>✅ Account Verified!</strong><br>Driver: ${found.name}<br>Valid until: <strong>${exp.toLocaleString()}</strong><br><span style="color:#a7f3d0">Auto-Accept Engine Ready</span>`;
  }

  // Backup Export
  exportBackup() {
    const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(this.drivers, null, 2));
    const dlAnchor = document.createElement('a');
    dlAnchor.setAttribute('href', dataStr);
    dlAnchor.setAttribute('download', `driving_care_backup_${new Date().toISOString().slice(0, 10)}.json`);
    document.body.appendChild(dlAnchor);
    dlAnchor.click();
    dlAnchor.remove();
    this.showToast('Backup JSON downloaded successfully!');
  }

  // Toast Notification
  showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = type === 'error' ? `<span>⚠️</span> ${message}` : `<span>✅</span> ${message}`;
    this.toastContainer.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 250);
    }, 3200);
  }

  // Compute Remaining Time Details
  getRemainingDetails(driver) {
    if (driver.status === 'pending') {
      return { text: 'Not Activated', pillClass: 'warning', percent: 0 };
    }
    if (!driver.expiresAt) {
      return { text: 'Expired', pillClass: 'danger', percent: 0 };
    }

    const now = new Date();
    const exp = new Date(driver.expiresAt);
    const diffMs = exp - now;

    if (diffMs <= 0) {
      // Auto update status if expired
      if (driver.status !== 'expired') {
        driver.status = 'expired';
        this.saveDrivers(this.drivers);
      }
      return { text: 'Expired (0d)', pillClass: 'danger', percent: 0 };
    }

    const days = Math.floor(diffMs / (24 * 60 * 60 * 1000));
    const hours = Math.floor((diffMs % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));

    const totalDuration = 30 * 24 * 60 * 60 * 1000;
    const percent = Math.min(100, Math.max(0, Math.round((diffMs / totalDuration) * 100)));

    let pillClass = '';
    if (days <= 3) pillClass = 'danger';
    else if (days <= 7) pillClass = 'warning';

    return {
      text: `${days}d ${hours}h left`,
      days,
      pillClass,
      percent
    };
  }

  // Render Full Application
  render() {
    this.updateStats();
    this.renderTable();
  }

  updateStats() {
    const total = this.drivers.length;
    let active = 0;
    let expiring = 0;
    let expired = 0;
    let pending = 0;
    let totalRevSAR = 0;

    const now = new Date();

    let totalMyShareSAR = 0;
    let totalClientShareSAR = 0;

    this.drivers.forEach(d => {
      const price = parseFloat(d.salePrice || d.feeSAR || 40);
      const comm = parseFloat(d.commissionPercent || 30);
      const myP = d.myShare !== undefined ? parseFloat(d.myShare) : (price * (comm / 100));
      const clientP = d.clientShare !== undefined ? parseFloat(d.clientShare) : (price - myP);

      if (d.status === 'pending') {
        pending++;
      } else {
        const exp = d.expiresAt ? new Date(d.expiresAt) : null;
        if (exp && exp > now) {
          active++;
          totalRevSAR += price;
          totalMyShareSAR += myP;
          totalClientShareSAR += clientP;
          const daysLeft = (exp - now) / (24 * 60 * 60 * 1000);
          if (daysLeft <= 3) expiring++;
        } else {
          expired++;
          // Still count historical revenue if sold
          totalRevSAR += price;
          totalMyShareSAR += myP;
          totalClientShareSAR += clientP;
        }
      }
    });

    // Financial calculations (30% - 40% Share)
    const ikramShareSAR = Math.round(totalMyShareSAR);
    const ikramSharePKR = Math.round(ikramShareSAR * SAR_TO_PKR_RATE);
    const clientShareSAR = Math.round(totalClientShareSAR);

    // Update DOM stats
    this.totalDriversCount.textContent = total;
    this.activeLicensesCount.textContent = active;
    this.expiredLicensesCount.textContent = `${expired + pending}`;
    this.totalRevenueSAR.innerHTML = `${totalRevSAR.toLocaleString()} <span class="currency">SAR</span>`;
    this.ikramShareText.textContent = `${ikramShareSAR.toLocaleString()} SAR (~${ikramSharePKR.toLocaleString()} PKR)`;
    if (this.clientShareText) {
      this.clientShareText.textContent = `${clientShareSAR.toLocaleString()} SAR`;
    }

    // Update Counts on Filter Tabs
    this.countAll.textContent = total;
    this.countActive.textContent = active;
    this.countExpiring.textContent = expiring;
    this.countExpired.textContent = expired;
    this.countPending.textContent = pending;
  }

  renderTable() {
    const now = new Date();

    const filtered = this.drivers.filter(d => {
      // Tab filter
      if (this.activeFilter === 'active') {
        if (d.status !== 'active' || !d.expiresAt || new Date(d.expiresAt) <= now) return false;
      } else if (this.activeFilter === 'expiring') {
        if (d.status !== 'active' || !d.expiresAt) return false;
        const days = (new Date(d.expiresAt) - now) / (24 * 60 * 60 * 1000);
        if (days < 0 || days > 3) return false;
      } else if (this.activeFilter === 'expired') {
        if (d.status !== 'expired' && (!d.expiresAt || new Date(d.expiresAt) > now)) return false;
      } else if (this.activeFilter === 'pending') {
        if (d.status !== 'pending') return false;
      }

      // Search filter
      if (this.searchQuery) {
        const matchName = d.name.toLowerCase().includes(this.searchQuery);
        const matchPhone = d.phone.toLowerCase().includes(this.searchQuery);
        const matchKey = d.key.toLowerCase().includes(this.searchQuery);
        const matchCity = d.city.toLowerCase().includes(this.searchQuery);
        if (!matchName && !matchPhone && !matchKey && !matchCity) return false;
      }

      return true;
    });

    if (filtered.length === 0) {
      this.driversTableBody.innerHTML = '';
      this.emptyState.style.display = 'block';
      return;
    }

    this.emptyState.style.display = 'none';

    this.driversTableBody.innerHTML = filtered.map(d => {
      const rem = this.getRemainingDetails(d);
      const isLive = d.status === 'active' && rem.percent > 0;
      
      let badgeHtml = '';
      if (isLive) {
        badgeHtml = `<span class="badge badge-active">🟢 Active</span>`;
      } else if (d.status === 'pending') {
        badgeHtml = `<span class="badge badge-pending">🟡 Pending</span>`;
      } else {
        badgeHtml = `<span class="badge badge-expired">🔴 Expired</span>`;
      }

      // WhatsApp direct URL
      const cleanPhone = d.phone.replace(/[^0-9]/g, '');
      const waUrl = `https://wa.me/${cleanPhone}`;

      return `
        <tr>
          <td>
            <div class="driver-cell">
              <div class="driver-avatar">${d.name.charAt(0).toUpperCase()}</div>
              <div>
                <div class="driver-name">${d.name}</div>
                <div class="driver-phone">
                  ${d.phone}
                  <a href="${waUrl}" target="_blank" class="wa-link" title="Open WhatsApp">💬 WhatsApp</a>
                </div>
              </div>
            </div>
          </td>
          <td>
            <strong style="color: #60a5fa;">👤 ${d.sellerName || 'Client KSA'}</strong>
            <div style="font-size: 0.75rem; color: #94a3b8; margin-top: 2px;">📍 ${d.city}</div>
          </td>
          <td>
            <span class="key-code" onclick="portal.copyKey('${d.signedKey || d.key}')" title="Click to copy activation key">
              🔑 ${d.key} ${d.signedKey ? '<span style="font-size: 0.65rem; background: #10b981; color: #fff; padding: 2px 6px; border-radius: 4px; margin-left: 4px; font-weight: 700;">Signed ✔</span>' : ''}
            </span>
            <div style="font-size: 0.72rem; color: #94a3b8; margin-top: 4px;">
              📱 Device: <strong style="color: ${d.boundDeviceId ? '#10b981' : '#f59e0b'}">${d.boundDeviceId ? d.boundDeviceId.substring(0, 10) + '...' : 'Available'}</strong>
            </div>
          </td>
          <td>
            <div style="font-size: 0.95rem; font-weight: 800; color: #fff;">${d.salePrice || d.feeSAR || 40} SAR</div>
            <div style="font-size: 0.75rem; color: #34d399; font-weight: 700; margin-top: 2px;">
              My Profit: ${(d.myShare !== undefined ? d.myShare : ((d.salePrice || 40) * 0.3)).toFixed(0)} SAR (${d.commissionPercent || 30}%)
            </div>
            <div style="font-size: 0.72rem; color: #94a3b8;">
              Client Share: ${(d.clientShare !== undefined ? d.clientShare : ((d.salePrice || 40) * 0.7)).toFixed(0)} SAR
            </div>
          </td>
          <td>
            ${badgeHtml}
            <div style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px;">
              ${d.expiresAt ? 'Expires: ' + new Date(d.expiresAt).toLocaleDateString('en-GB') : 'No expiry set'}
            </div>
          </td>
          <td>
            <span class="time-text">${rem.text}</span>
            ${d.status === 'active' ? `
              <div class="progress-pill">
                <div class="progress-fill ${rem.pillClass}" style="width: ${rem.percent}%"></div>
              </div>
            ` : ''}
          </td>
          <td class="text-right">
            <div class="action-btns">
              ${d.status === 'pending' ? `
                <button class="btn btn-sm btn-primary" onclick="portal.activateDriver('${d.id}')" title="Mark Paid & Start 30 Days">
                  ▶ Activate
                </button>
              ` : `
                <button class="btn btn-sm btn-secondary" onclick="portal.renewDriver('${d.id}')" title="Add 30 Days Renewal">
                  🔄 Renew (+30d)
                </button>
              `}
              <button class="btn btn-sm btn-outline" onclick="portal.resetDeviceBinding('${d.key}')" title="Reset Bound Device (Phone)" style="color: #fbbf24; border-color: #f59e0b;">
                🔓 Reset Device
              </button>
              <button class="btn btn-sm btn-outline" onclick="portal.copyDriverWhatsApp('${d.id}')" title="Copy Ready WhatsApp Message">
                📋 Send Key
              </button>
              <button class="btn btn-sm btn-outline" onclick="portal.deleteDriver('${d.id}')" title="Delete Driver" style="color: #f87171;">
                🗑️
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  startLivePolling() {
    const poll = async () => {
      if (!this.adminToken) return;
      try {
        const res = await fetch('/api/admin/drivers', {
          headers: {
            'Authorization': 'Bearer ' + this.adminToken,
            'X-Admin-Token': this.adminToken
          }
        });
        if (res.status === 401) {
          localStorage.removeItem('dc_admin_token');
          this.adminToken = null;
          if (this.adminLoginModal) this.adminLoginModal.style.display = 'flex';
          if (this.loginErrorAlert) {
            this.loginErrorAlert.textContent = 'Session expired. Please enter password again.';
            this.loginErrorAlert.style.display = 'block';
          }
          return;
        }
        if (res.ok) {
          const data = await res.json();
          if (data && data.drivers) {
            this.drivers = data.drivers.map((d, index) => ({
              id: 'd_' + index,
              sellerName: d.sellerName || 'Client KSA',
              name: d.name,
              phone: d.phone,
              city: d.city,
              key: d.key,
              signedKey: d.signedKey || null,
              boundDeviceId: d.boundDeviceId || null,
              salePrice: d.salePrice || d.feeSAR || 40,
              feeSAR: d.salePrice || d.feeSAR || 40,
              commissionPercent: d.commissionPercent || 30,
              myShare: d.myShare !== undefined ? d.myShare : (d.salePrice || 40) * 0.3,
              clientShare: d.clientShare !== undefined ? d.clientShare : (d.salePrice || 40) * 0.7,
              status: d.status,
              online: d.online,
              device: d.device || 'Android Phone',
              ip: d.ip || '-',
              daysLeft: d.daysLeft || 30,
              activatedAt: d.activatedAt || new Date().toISOString(),
              expiresAt: d.activeUntil ? new Date(d.activeUntil).toISOString() : new Date(Date.now() + (d.daysLeft || 30) * 24 * 60 * 60 * 1000).toISOString()
            }));
            this.render();
          }
        }
      } catch (e) {
        // Fallback local mode
      }
    };
    poll();
    setInterval(poll, 3000);
  }
}

// Global instance for inline onclick handlers
let portal;
document.addEventListener('DOMContentLoaded', () => {
  portal = new DrivingCarePortal();
});
