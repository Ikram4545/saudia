// Driving Care Portal - Core Application Logic
// Designed for Bilal (Owner) & Ikram (Technical Partner - 40% Share)

const STORAGE_KEY = 'driving_care_drivers_v1';
const SAR_TO_PKR_RATE = 74.5; // Approximate exchange rate

class DrivingCarePortal {
  constructor() {
    this.adminToken = localStorage.getItem('dc_admin_token');
    this.drivers = this.loadDrivers();
    this.activeFilter = 'all';
    this.searchQuery = '';
    this.pollingInterval = null;
    this.isPollingBusy = false;

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
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      } catch (e) {
        console.error('Failed to parse drivers storage', e);
      }
    }
    return [];
  }

  saveDrivers(data) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } catch (e) {
      console.warn('LocalStorage save failed:', e);
    }
  }

  // Admin Authentication Gate Management
  initAuth() {
    if (this.toggleAdminPwBtn && this.adminPasswordInput) {
      this.toggleAdminPwBtn.addEventListener('click', () => {
        const isPw = this.adminPasswordInput.type === 'password';
        this.adminPasswordInput.type = isPw ? 'text' : 'password';
        this.toggleAdminPwBtn.textContent = isPw ? '🔒' : '👁️';
      });
    }

    if (!this.adminToken) {
      if (this.adminLoginModal) this.adminLoginModal.style.display = 'flex';
    } else {
      if (this.adminLoginModal) this.adminLoginModal.style.display = 'none';
    }

    if (this.adminLoginForm) {
      this.adminLoginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = this.adminUsernameInput ? this.adminUsernameInput.value.trim() : '';
        const password = this.adminPasswordInput ? this.adminPasswordInput.value.trim() : '';
        if (this.loginErrorAlert) this.loginErrorAlert.style.display = 'none';

        try {
          const res = await fetch('/api/admin_login.php', {
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
          if (this.loginErrorAlert) {
            this.loginErrorAlert.textContent = 'Server connection error. Please try again.';
            this.loginErrorAlert.style.display = 'block';
          }
        }
      });
    }

    if (this.adminLogoutBtn) {
      this.adminLogoutBtn.addEventListener('click', () => {
        if (confirm('Admin panel ko lock aur logout karna chahte hain?')) {
          localStorage.removeItem('dc_admin_token');
          this.adminToken = null;
          if (this.pollingInterval) clearInterval(this.pollingInterval);
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
    this.clientShareText = document.getElementById('clientShareText');

    // Counts on Filter Tabs
    this.countAll = document.getElementById('countAll');
    this.countActive = document.getElementById('countActive');
    this.countExpiring = document.getElementById('countExpiring');
    this.countExpired = document.getElementById('countExpired');
    this.countReset = document.getElementById('countReset');
    this.countPending = document.getElementById('countPending');

    // Table & Empty State
    this.driversTableBody = document.getElementById('driversTableBody');
    this.emptyState = document.getElementById('emptyState');

    // Filter controls
    this.tabButtons = document.querySelectorAll('.tab-btn');
    this.searchInput = document.getElementById('searchInput');

    // Modals
    this.addDriverModal = document.getElementById('addDriverModal');
    this.addDriverBtn = document.getElementById('addDriverBtn');
    this.closeModalBtn = document.getElementById('closeModalBtn');
    this.cancelDriverBtn = document.getElementById('cancelDriverBtn');
    this.driverForm = document.getElementById('driverForm');
    this.regenerateKeyBtn = document.getElementById('regenerateKeyBtn');

    // Form inputs
    this.driverNameInput = document.getElementById('driverName');
    this.driverPhoneInput = document.getElementById('driverPhone');
    this.driverCityInput = document.getElementById('driverCity');
    this.driverKeyInput = document.getElementById('driverKey');
    this.driverSalePriceInput = document.getElementById('driverSalePrice');
    this.sellerNameInput = document.getElementById('sellerName');
    this.calcPreviewBox = document.getElementById('calcPreviewBox');

    // Simulator
    this.simulatorModal = document.getElementById('simulatorModal');
    this.openSimulatorBtn = document.getElementById('openSimulatorBtn');
    this.closeSimulatorBtn = document.getElementById('closeSimulatorBtn');
    this.simKeyInput = document.getElementById('simKeyInput');
    this.simVerifyBtn = document.getElementById('simVerifyBtn');
    this.simResultBox = document.getElementById('simResultBox');

    // Export Data
    this.exportDataBtn = document.getElementById('exportDataBtn');

    // Toast
    this.toastContainer = document.getElementById('toastContainer');

    // Batch Keys Modal
    this.batchKeysBtn = document.getElementById('batchKeysBtn');
    this.batchModal = document.getElementById('batchModal');
    this.closeBatchModalBtn = document.getElementById('closeBatchModalBtn');
    this.cancelBatchBtn = document.getElementById('cancelBatchBtn');
    this.batchForm = document.getElementById('batchForm');
    this.batchCountInput = document.getElementById('batchCount');
    this.batchSellerSelect = document.getElementById('batchSeller');
    this.batchPriceInput = document.getElementById('batchPrice');

    // Login Gate Elements
    this.adminLoginModal = document.getElementById('adminLoginModal');
    this.adminLoginForm = document.getElementById('adminLoginForm');
    this.adminUsernameInput = document.getElementById('adminUsernameInput');
    this.adminPasswordInput = document.getElementById('adminPasswordInput');
    this.toggleAdminPwBtn = document.getElementById('toggleAdminPwBtn');
    this.loginErrorAlert = document.getElementById('loginErrorAlert');
    this.adminLogoutBtn = document.getElementById('adminLogoutBtn');
  }

  bindEvents() {
    // Filter tabs
    this.tabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        this.tabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.activeFilter = btn.dataset.filter || 'all';
        this.renderTable();
      });
    });

    // Search input
    if (this.searchInput) {
      this.searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value.toLowerCase().trim();
        this.renderTable();
      });
    }

    // Add Driver Modal Open/Close
    if (this.addDriverBtn) this.addDriverBtn.addEventListener('click', () => this.openAddModal());
    if (this.closeModalBtn) this.closeModalBtn.addEventListener('click', () => this.closeAddModal());
    if (this.cancelDriverBtn) this.cancelDriverBtn.addEventListener('click', () => this.closeAddModal());
    if (this.regenerateKeyBtn) this.regenerateKeyBtn.addEventListener('click', () => this.generateRandomKey());

    // Submit Driver Form
    if (this.driverForm) {
      this.driverForm.addEventListener('submit', (e) => {
        e.preventDefault();
        this.handleSaveDriver();
      });
    }

    // Simulator Modal
    if (this.openSimulatorBtn && this.simulatorModal) {
      this.openSimulatorBtn.addEventListener('click', () => {
        this.simulatorModal.style.display = 'flex';
      });
    }
    if (this.closeSimulatorBtn && this.simulatorModal) {
      this.closeSimulatorBtn.addEventListener('click', () => {
        this.simulatorModal.style.display = 'none';
      });
    }
    if (this.simVerifyBtn) {
      this.simVerifyBtn.addEventListener('click', () => this.handleSimulateVerify());
    }

    // Export Data
    if (this.exportDataBtn) {
      this.exportDataBtn.addEventListener('click', () => this.exportBackup());
    }

    // Batch Keys Modal
    if (this.batchKeysBtn && this.batchModal) {
      this.batchKeysBtn.addEventListener('click', () => {
        this.batchModal.style.display = 'flex';
      });
      if (this.closeBatchModalBtn) {
        this.closeBatchModalBtn.addEventListener('click', () => {
          this.batchModal.style.display = 'none';
        });
      }
      if (this.cancelBatchBtn) {
        this.cancelBatchBtn.addEventListener('click', () => {
          this.batchModal.style.display = 'none';
        });
      }
      if (this.batchForm) {
        this.batchForm.addEventListener('submit', (e) => {
          e.preventDefault();
          this.handleBatchCreate();
        });
      }
    }
  }

  generateRandomKey() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    let p1 = '', p2 = '';
    for (let i = 0; i < 4; i++) p1 += chars.charAt(Math.floor(Math.random() * chars.length));
    for (let i = 0; i < 4; i++) p2 += chars.charAt(Math.floor(Math.random() * chars.length));
    if (this.driverKeyInput) this.driverKeyInput.value = `DC-${p1}-${p2}`;
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
    const comm = parseFloat(commInput ? commInput.value : 40);
    const myShare = (price * (comm / 100)).toFixed(1);
    const clientShare = (price - myShare).toFixed(1);
    if (this.calcPreviewBox) {
      this.calcPreviewBox.innerHTML = `Selling: <strong>${price} SAR</strong> ➔ <strong>My Share: ${myShare} SAR (${comm}%)</strong> | Client Share: <strong>${clientShare} SAR (${100 - comm}%)</strong>`;
    }
  }

  openAddModal() {
    if (!this.addDriverModal) return;
    this.addDriverModal.style.display = 'flex';
    this.generateRandomKey();
    if (this.driverNameInput) this.driverNameInput.value = '';
    if (this.driverPhoneInput) this.driverPhoneInput.value = '+966 ';
    if (this.driverCityInput) this.driverCityInput.value = 'Riyadh';
    if (this.driverSalePriceInput) this.driverSalePriceInput.value = '40';
    this.updateProfitPreview();
  }

  closeAddModal() {
    if (this.addDriverModal) this.addDriverModal.style.display = 'none';
  }

  async handleSaveDriver() {
    const name = this.driverNameInput.value.trim();
    const phone = this.driverPhoneInput.value.trim();
    const city = this.driverCityInput.value.trim();
    const key = this.driverKeyInput.value.trim().toUpperCase();
    const salePrice = parseFloat(this.driverSalePriceInput.value) || 40;
    const sellerName = this.sellerNameInput ? this.sellerNameInput.value : 'Client KSA';

    const commInput = document.querySelector('input[name="commissionPercent"]:checked');
    const comm = parseFloat(commInput ? commInput.value : 40);
    const myShare = parseFloat((salePrice * (comm / 100)).toFixed(1));
    const clientShare = parseFloat((salePrice - myShare).toFixed(1));

    if (!key) {
      alert('License key zaroori hai.');
      return;
    }

    try {
      const res = await fetch('/api/admin_create_key.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (this.adminToken || localStorage.getItem('dc_admin_token') || ''),
          'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
        },
        body: JSON.stringify({
          key, name: name || 'Driver', phone, city,
          salePrice, commissionPercent: comm, sellerName,
          status: 'pending'
        })
      });
      const data = await res.json();
      if (data.success) {
        this.showToast(`Key ${key} created successfully! (Pending Payment)`);
        this.closeAddModal();
        if (this.adminToken) this.pollServer();
      } else {
        alert(data.message || 'Error creating key.');
      }
    } catch (e) {
      alert('Server communication error: ' + e.message);
    }
  }

  async handleBatchCreate() {
    const count = parseInt(this.batchCountInput?.value || '10');
    const seller = this.batchSellerSelect?.value || 'Client KSA';
    const price = parseFloat(this.batchPriceInput?.value || '40');
    const commInput = document.querySelector('input[name="batchComm"]:checked');
    const comm = parseFloat(commInput ? commInput.value : '40');

    try {
      const res = await fetch('/api/admin_batch_create_keys.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (this.adminToken || localStorage.getItem('dc_admin_token') || ''),
          'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
        },
        body: JSON.stringify({ count, seller, price, commissionPercent: comm })
      });
      const data = await res.json();
      if (data.success) {
        this.showToast(`${data.createdCount || count} keys successfully generated!`);
        if (this.batchModal) this.batchModal.style.display = 'none';
        if (this.adminToken) this.pollServer();
      } else {
        this.showToast(data.message || 'Error generating batch keys', 'error');
      }
    } catch (e) {
      this.showToast('Network error while generating batch keys', 'error');
    }
  }

  // 1-Click Approve & Activate (Starts 30 Days and Binds Device)
  async activateDriver(key) {
    const driver = this.drivers.find(d => (d.key === key || d.id === key));
    if (!driver) return;

    if (!confirm(`Driver Key "${driver.key}" ko Approve & Activate karna chahte hain?\n(Is driver ke 30 Din shuru ho jayenge).`)) return;

    try {
      const res = await fetch('/api/admin_toggle_driver.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (this.adminToken || localStorage.getItem('dc_admin_token') || ''),
          'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
        },
        body: JSON.stringify({ key: driver.key, status: 'active' })
      });
      const data = await res.json();
      if (data.success) {
        const now = Date.now();
        driver.status = 'active';
        driver.activeUntil = now + (30 * 86400 * 1000);
        driver.expiresAt = new Date(driver.activeUntil).toISOString();
        driver.daysLeft = 30;
        if (!driver.boundDeviceId && driver.requestedDeviceId) {
          driver.boundDeviceId = driver.requestedDeviceId;
        }
        this.saveDrivers(this.drivers);
        this.render();
        this.showToast(`Key ${driver.key} Approved & Activated for 30 Days!`);
        // Refresh from server
        setTimeout(() => this.pollServer(), 1000);
      } else {
        this.showToast(data.message || data.error || 'Activation fail ho gayi.', 'error');
      }
    } catch (e) {
      this.showToast('Network error while activating: ' + e.message, 'error');
    }
  }

  // 1-Click Monthly Renewal / Re-Activation (+30 Days)
  async renewDriver(key) {
    const driver = this.drivers.find(d => (d.key === key || d.id === key));
    if (!driver) return;

    if (!confirm(`Driver "${driver.name || driver.key}" ko +30 Din ke liye Renew / Re-activate karna chahte hain?`)) return;

    try {
      const res = await fetch('/api/admin_toggle_driver.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (this.adminToken || localStorage.getItem('dc_admin_token') || ''),
          'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
        },
        body: JSON.stringify({ key: driver.key, status: 'active' })
      });
      const data = await res.json();
      if (data.success) {
        const now = Date.now();
        const base = (driver.status === 'active' && driver.activeUntil && driver.activeUntil > now)
          ? driver.activeUntil
          : now;
        driver.status = 'active';
        driver.activeUntil = base + (30 * 86400 * 1000);
        driver.expiresAt = new Date(driver.activeUntil).toISOString();
        driver.daysLeft = Math.max(1, Math.round((driver.activeUntil - now) / 86400000));
        this.saveDrivers(this.drivers);
        this.render();
        this.showToast(`Renewed! ${driver.name || driver.key} extended by +30 Days.`);
        setTimeout(() => this.pollServer(), 1000);
      } else {
        this.showToast(data.message || data.error || 'Renewal fail ho gaya.', 'error');
      }
    } catch (e) {
      this.showToast('Network error while renewing: ' + e.message, 'error');
    }
  }

  // Reset Bound Device (Hardware ID lock)
  async resetDeviceBinding(key) {
    if (!confirm(`Driver key "${key}" ki Device Binding reset karni hai?\n(Is se key naye phone par login ho sakegi).`)) return;

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
        const target = this.drivers.find(d => d.key === key);
        if (target) {
          target.boundDeviceId = null;
          target.status = 'pending';
          target.device = 'Reset (Pending Approval)';
          this.saveDrivers(this.drivers);
        }
        this.render();
        this.showToast(data.message || `Device binding reset for ${key}! Naya phone bind ho sakega.`);
        setTimeout(() => this.pollServer(), 1000);
      } else {
        this.showToast(data.message || data.error || 'Reset fail ho gaya.', 'error');
      }
    } catch (e) {
      this.showToast('Network error while resetting device: ' + e.message, 'error');
    }
  }

  // Delete Driver Permanently
  async deleteDriver(key) {
    const driver = this.drivers.find(d => (d.key === key || d.id === key));
    if (!driver) return;

    if (!confirm(`Kia aap waqai Driver "${driver.name || driver.key}" ko delete karna chahte hain?\nYeh key hamesha ke liye delete ho jayegi.`)) return;

    try {
      const res = await fetch('/api/admin_delete_driver.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (this.adminToken || localStorage.getItem('dc_admin_token') || ''),
          'X-Admin-Token': this.adminToken || localStorage.getItem('dc_admin_token') || ''
        },
        body: JSON.stringify({ key: driver.key })
      });
      const data = await res.json();
      if (data.success) {
        this.drivers = this.drivers.filter(d => d.key !== driver.key);
        this.saveDrivers(this.drivers);
        this.render();
        this.showToast(`Driver ${driver.name || driver.key} permanently deleted.`);
        setTimeout(() => this.pollServer(), 1000);
      } else {
        this.showToast(data.message || data.error || 'Delete fail ho gaya.', 'error');
      }
    } catch (e) {
      this.showToast('Network error while deleting: ' + e.message, 'error');
    }
  }

  copyDriverWhatsApp(key) {
    const driver = this.drivers.find(d => (d.key === key || d.id === key));
    if (!driver) return;

    const licenseKey = driver.signedKey || driver.key;
    const msg = `*Driving Care - Saudi Arabia Ride Bot*\n\nAssalam o Alaikum ${driver.name},\nAapki activation key yeh hai:\n\n*Key:* \`${licenseKey}\`\n\nApp Download Link:\nhttps://drivewithbilal.com/Driving_Care_v2.5_Production.apk\n\n*Tariqa-e-Kaar:*\n1. App install karein aur Accessibility On karein\n2. Key darj karein aur Login dabayein\n3. Ye key sirf aapke mobile ke sath bind ho jayegi.\n\nShukriya!\nSupport: +966 53 419 9549`;

    navigator.clipboard.writeText(msg).then(() => {
      this.showToast(`WhatsApp message copied for ${driver.name || driver.key}!`);
    }).catch(() => {
      prompt('Copy message:', msg);
    });
  }

  copyKey(key) {
    navigator.clipboard.writeText(key).then(() => {
      this.showToast(`Copied key: ${key}`);
    }).catch(() => {
      prompt('Copy key:', key);
    });
  }

  handleSimulateVerify() {
    const key = this.simKeyInput?.value.trim().toUpperCase();
    if (!key) {
      alert('Key darj karein');
      return;
    }
    const driver = this.drivers.find(d => d.key.toUpperCase() === key);
    if (!driver) {
      if (this.simResultBox) {
        this.simResultBox.style.display = 'block';
        this.simResultBox.className = 'sim-result-box sim-fail';
        this.simResultBox.innerHTML = `❌ Key nahi mili! Database mein aisi koi key mojood nahi hai.`;
      }
      return;
    }
    const rem = this.getRemainingDetails(driver);
    if (this.simResultBox) {
      this.simResultBox.style.display = 'block';
      if (driver.status === 'active' && rem.days > 0) {
        this.simResultBox.className = 'sim-result-box sim-success';
        this.simResultBox.innerHTML = `✅ <strong>Access Granted!</strong><br>Driver: ${driver.name}<br>Status: Active (${rem.text})<br>Device: ${driver.boundDeviceId || 'Unbound'}`;
      } else if (driver.status === 'pending') {
        this.simResultBox.className = 'sim-result-box sim-warning';
        this.simResultBox.innerHTML = `⚠️ <strong>Pending Payment!</strong><br>Ye key abhi inactive hai. Admin ki taraf se approval zaroori hai.`;
      } else {
        this.simResultBox.className = 'sim-result-box sim-fail';
        this.simResultBox.innerHTML = `❌ <strong>Expired!</strong><br>Driver license expire ho chuka hai. Renewal darkar hai.`;
      }
    }
  }

  exportBackup() {
    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(this.drivers, null, 2));
    const dlAnchorElem = document.createElement('a');
    dlAnchorElem.setAttribute("href", dataStr);
    dlAnchorElem.setAttribute("download", `driving_care_backup_${new Date().toISOString().slice(0, 10)}.json`);
    dlAnchorElem.click();
    this.showToast('Database backup downloaded successfully.');
  }

  showToast(message, type = 'success') {
    if (!this.toastContainer) return;
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    this.toastContainer.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      setTimeout(() => toast.remove(), 300);
    }, 3200);
  }

  getRemainingDetails(driver) {
    if (driver.status === 'pending') {
      return { text: 'Not Activated', pillClass: 'warning', percent: 0, days: 0, isPending: true };
    }

    const now = Date.now();
    let expMs = 0;
    if (driver.activeUntil) {
      expMs = parseInt(driver.activeUntil);
    } else if (driver.expiresAt) {
      expMs = new Date(driver.expiresAt).getTime();
    } else if (driver.daysLeft) {
      expMs = now + (driver.daysLeft * 86400 * 1000);
    }

    if (!expMs || expMs <= now) {
      return { text: 'Expired (0d)', pillClass: 'danger', percent: 0, days: 0, isExpired: true };
    }

    const diffMs = expMs - now;
    const days = Math.floor(diffMs / (24 * 60 * 60 * 1000));
    const hours = Math.floor((diffMs % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const percent = Math.min(100, Math.max(5, Math.round((days / 30) * 100)));

    let pillClass = '';
    if (days <= 3) pillClass = 'danger';
    else if (days <= 7) pillClass = 'warning';
    else pillClass = 'success';

    return {
      text: `${days}d ${hours}h left`,
      days,
      hours,
      pillClass,
      percent,
      isExpiringSoon: (days <= 3)
    };
  }

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
    let reset = 0;
    let totalRevSAR = 0;
    let totalMyShareSAR = 0;
    let totalClientShareSAR = 0;

    this.drivers.forEach(d => {
      const price = parseFloat(d.salePrice || d.feeSAR || 40);
      const comm = parseFloat(d.commissionPercent || 40);
      const myP = d.myShare !== undefined ? parseFloat(d.myShare) : (price * (comm / 100));
      const clientP = d.clientShare !== undefined ? parseFloat(d.clientShare) : (price - myP);

      const isReset = (d.device && d.device.includes('Reset')) || d.isReset === true || d.bilalStatus === 'device_reset';
      if (isReset) {
        reset++;
      }
      if (d.status === 'pending') {
        if (!isReset) pending++;
      } else {
        const rem = this.getRemainingDetails(d);
        if (d.status === 'active' && rem.days > 0) {
          active++;
          totalRevSAR += price;
          totalMyShareSAR += myP;
          totalClientShareSAR += clientP;
          if (rem.days <= 3) expiring++;
        } else {
          expired++;
          totalRevSAR += price;
          totalMyShareSAR += myP;
          totalClientShareSAR += clientP;
        }
      }
    });

    const ikramShareSAR = Math.round(totalMyShareSAR);
    const ikramSharePKR = Math.round(ikramShareSAR * SAR_TO_PKR_RATE);
    const clientShareSAR = Math.round(totalClientShareSAR);

    // Update DOM stats safely
    if (this.totalDriversCount) this.totalDriversCount.textContent = total;
    if (this.activeLicensesCount) this.activeLicensesCount.textContent = active;
    if (this.expiredLicensesCount) this.expiredLicensesCount.textContent = `${expired + pending}`;
    if (this.totalRevenueSAR) this.totalRevenueSAR.innerHTML = `${totalRevSAR.toLocaleString()} <span class="currency">SAR</span>`;
    if (this.ikramShareText) this.ikramShareText.textContent = `${ikramShareSAR.toLocaleString()} SAR (~${ikramSharePKR.toLocaleString()} PKR)`;
    if (this.clientShareText) this.clientShareText.textContent = `${clientShareSAR.toLocaleString()} SAR`;

    // Update Counts on Filter Tabs safely
    if (this.countAll) this.countAll.textContent = total;
    if (this.countActive) this.countActive.textContent = active;
    if (this.countExpiring) this.countExpiring.textContent = expiring;
    if (this.countExpired) this.countExpired.textContent = expired;
    if (this.countReset) this.countReset.textContent = reset;
    if (this.countPending) this.countPending.textContent = pending;
  }

  renderTable() {
    if (!this.driversTableBody) return;

    const filtered = this.drivers.filter(d => {
      const rem = this.getRemainingDetails(d);

      // Tab filter
      const isReset = (d.device && d.device.includes('Reset')) || d.isReset === true || d.bilalStatus === 'device_reset';
      if (this.activeFilter === 'active') {
        if (d.status !== 'active' || rem.days <= 0) return false;
      } else if (this.activeFilter === 'expiring') {
        if (d.status !== 'active' || rem.days <= 0 || rem.days > 3) return false;
      } else if (this.activeFilter === 'expired') {
        if (d.status === 'pending') return false;
        if (d.status !== 'expired' && rem.days > 0) return false;
      } else if (this.activeFilter === 'reset') {
        if (!isReset) return false;
      } else if (this.activeFilter === 'pending') {
        if (d.status !== 'pending' || isReset) return false;
      }

      // Search filter
      if (this.searchQuery) {
        const q = this.searchQuery;
        const matchName = (d.name || '').toLowerCase().includes(q);
        const matchPhone = (d.phone || '').toLowerCase().includes(q);
        const matchKey = (d.key || '').toLowerCase().includes(q);
        const matchCity = (d.city || '').toLowerCase().includes(q);
        if (!matchName && !matchPhone && !matchKey && !matchCity) return false;
      }

      return true;
    });

    if (filtered.length === 0) {
      this.driversTableBody.innerHTML = '';
      if (this.emptyState) this.emptyState.style.display = 'block';
      return;
    }

    if (this.emptyState) this.emptyState.style.display = 'none';

    this.driversTableBody.innerHTML = filtered.map(d => {
      const rem = this.getRemainingDetails(d);
      const isLive = d.status === 'active' && rem.days > 0;
      const isPending = d.status === 'pending';
      const isExpired = !isPending && (!isLive || d.status === 'expired');

      let badgeHtml = '';
      if (isPending) {
        badgeHtml = `<span class="badge badge-pending">🟡 Pending Payment</span>`;
      } else if (isLive) {
        if (rem.days <= 3) {
          badgeHtml = `<span class="badge badge-warning" style="background: rgba(245, 158, 11, 0.2); color: #fbbf24; border: 1px solid rgba(245, 158, 11, 0.4);">🟠 Expiring Soon (${rem.days}d)</span>`;
        } else {
          badgeHtml = `<span class="badge badge-active">🟢 Active</span>`;
        }
      } else {
        badgeHtml = `<span class="badge badge-expired">🔴 Expired</span>`;
      }

      const cleanPhone = (d.phone || '').replace(/[^0-9]/g, '');
      const waUrl = cleanPhone ? `https://wa.me/${cleanPhone}` : '#';

      const salePriceNum = parseFloat(d.salePrice || d.feeSAR || 40) || 40;
      const commPercentNum = parseFloat(d.commissionPercent || 40) || 40;
      const myShareNum = (d.myShare !== undefined && d.myShare !== null && d.myShare !== '')
        ? (parseFloat(d.myShare) || 0)
        : (salePriceNum * (commPercentNum / 100));
      const clientShareNum = (d.clientShare !== undefined && d.clientShare !== null && d.clientShare !== '')
        ? (parseFloat(d.clientShare) || 0)
        : (salePriceNum - myShareNum);
      const boundDevStr = d.boundDeviceId ? String(d.boundDeviceId) : '';
      const reqDevStr = d.requestedDeviceId ? String(d.requestedDeviceId) : '';

      // Action buttons
      let actionPrimary = '';
      if (isPending) {
        actionPrimary = `
          <button class="btn btn-sm btn-approve" style="background: linear-gradient(135deg, #10b981, #059669); color: #fff; font-weight: 700; border: none; padding: 7px 12px; border-radius: 6px; box-shadow: 0 2px 8px rgba(16, 185, 129, 0.35); cursor: pointer;" onclick="portal.activateDriver('${d.key}')" title="Approve Request & Start 30 Days">
            ▶ Approve & Activate
          </button>
        `;
      } else if (isExpired) {
        actionPrimary = `
          <button class="btn btn-sm btn-renew" style="background: linear-gradient(135deg, #3b82f6, #1d4ed8); color: #fff; font-weight: 700; border: none; padding: 7px 12px; border-radius: 6px; box-shadow: 0 2px 8px rgba(59, 130, 246, 0.35); cursor: pointer;" onclick="portal.renewDriver('${d.key}')" title="Reactivate for +30 Days">
            🔄 Re-Activate (+30d)
          </button>
        `;
      } else {
        actionPrimary = `
          <button class="btn btn-sm btn-secondary" style="background: rgba(59, 130, 246, 0.2); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.4); padding: 7px 12px; border-radius: 6px; font-weight: 600; cursor: pointer;" onclick="portal.renewDriver('${d.key}')" title="Extend +30 Days Renewal">
            🔄 Renew (+30d)
          </button>
        `;
      }

      return `
        <tr class="driver-row" data-key="${d.key}">
          <td data-label="Driver Details">
            <div class="driver-cell">
              <div class="driver-avatar">${(d.name || 'D').charAt(0).toUpperCase()}</div>
              <div>
                <div class="driver-name">${d.name || 'Unassigned Driver'}</div>
                <div class="driver-phone">
                  ${d.phone || 'No Phone'}
                  ${cleanPhone ? `<a href="${waUrl}" target="_blank" class="wa-link" title="Open WhatsApp">💬 WhatsApp</a>` : ''}
                </div>
              </div>
            </div>
          </td>
          <td data-label="Seller & Region">
            <strong style="color: #60a5fa;">👤 ${d.sellerName || 'Client KSA'}</strong>
            <div style="font-size: 0.75rem; color: #94a3b8; margin-top: 2px;">📍 ${d.city || 'Saudi Arabia'}</div>
          </td>
          <td data-label="License Key & Device">
            <span class="key-code" onclick="portal.copyKey('${d.signedKey || d.key}')" title="Click to copy activation key">
              🔑 ${d.key} ${d.signedKey ? '<span style="font-size: 0.65rem; background: #10b981; color: #fff; padding: 2px 6px; border-radius: 4px; margin-left: 4px; font-weight: 700;">Signed ✔</span>' : ''}
            </span>
            <div style="font-size: 0.72rem; color: #94a3b8; margin-top: 4px;">
              📱 Device: <strong style="color: ${boundDevStr ? '#10b981' : (reqDevStr ? '#38bdf8' : '#f59e0b')}">${boundDevStr ? boundDevStr.substring(0, 10) + '...' : (reqDevStr ? 'Req: ' + reqDevStr.substring(0, 8) + '...' : 'Available')}</strong>
              ${d.requestedAt ? `<div style="font-size: 0.68rem; color: #f59e0b;">⏳ Requested: ${d.requestedAt}</div>` : ''}
            </div>
          </td>
          <td data-label="Selling Price & Split">
            <div style="font-size: 0.95rem; font-weight: 800; color: #fff;">${salePriceNum} SAR</div>
            <div style="font-size: 0.75rem; color: #34d399; font-weight: 700; margin-top: 2px;">
              My Profit: ${myShareNum.toFixed(0)} SAR (${commPercentNum}%)
            </div>
            <div style="font-size: 0.72rem; color: #94a3b8;">
              Client Share: ${clientShareNum.toFixed(0)} SAR (${100 - commPercentNum}%)
            </div>
          </td>
          <td data-label="Status & Validity">
            ${badgeHtml}
            <div style="font-size: 0.72rem; color: #94a3b8; margin-top: 4px;">
              ${isPending ? 'Expires: 30 Days after activation' : (d.expiresAt ? 'Expires: ' + new Date(d.expiresAt).toLocaleDateString('en-GB') : 'Not Activated')}
            </div>
          </td>
          <td data-label="Remaining Time">
            <div class="time-remaining">
              <span class="time-pill ${rem.pillClass}">${rem.text}</span>
              ${isLive ? `
                <div class="progress-bar">
                  <div class="progress-fill" style="width: ${rem.percent}%"></div>
                </div>
              ` : ''}
            </div>
          </td>
          <td data-label="Actions">
            <div class="action-btns">
              ${actionPrimary}
              <button class="btn btn-sm btn-outline" onclick="portal.resetDeviceBinding('${d.key}')" title="Reset Bound Device (Phone)" style="color: #fbbf24; border-color: #f59e0b;">
                🔓 Reset Device
              </button>
              <button class="btn btn-sm btn-outline" onclick="portal.copyDriverWhatsApp('${d.key}')" title="Copy Ready WhatsApp Message">
                📋 Send Key
              </button>
              <button class="btn btn-sm btn-outline" onclick="portal.deleteDriver('${d.key}')" title="Delete Driver" style="color: #f87171;">
                🗑️
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  async pollServer() {
    if (!this.adminToken || this.isPollingBusy) return;
    this.isPollingBusy = true;
    try {
      const res = await fetch('/api/admin_drivers.php', {
        headers: {
          'Authorization': 'Bearer ' + this.adminToken,
          'X-Admin-Token': this.adminToken
        }
      });
      if (res.status === 401) {
        localStorage.removeItem('dc_admin_token');
        this.adminToken = null;
        if (this.pollingInterval) clearInterval(this.pollingInterval);
        if (this.adminLoginModal) this.adminLoginModal.style.display = 'flex';
        return;
      }
      if (res.ok) {
        const data = await res.json();
        if (data && data.drivers && Array.isArray(data.drivers)) {
          this.drivers = data.drivers.map((d, index) => ({
            id: 'd_' + index,
            sellerName: d.sellerName || 'Client KSA',
            name: d.name || 'Driver',
            phone: d.phone || '',
            city: d.city || 'Saudi Arabia',
            key: d.key,
            signedKey: d.signedKey || null,
            boundDeviceId: d.boundDeviceId || null,
            salePrice: d.salePrice || d.feeSAR || 40,
            feeSAR: d.salePrice || d.feeSAR || 40,
            commissionPercent: d.commissionPercent || 40,
            myShare: d.myShare !== undefined ? d.myShare : (d.salePrice || 40) * 0.4,
            clientShare: d.clientShare !== undefined ? d.clientShare : (d.salePrice || 40) * 0.6,
            status: d.status || 'pending',
            online: d.online || false,
            device: d.device || 'Android Phone',
            ip: d.ip || '-',
            daysLeft: d.daysLeft || 30,
            activatedAt: d.activatedAt || null,
            activeUntil: d.activeUntil || null,
            expiresAt: d.activeUntil ? new Date(d.activeUntil).toISOString() : null,
            requestedDeviceId: d.requestedDeviceId || null,
            requestedDevice: d.requestedDevice || null,
            requestedAt: d.requestedAt || null,
            settings: d.settings || null
          }));
          this.saveDrivers(this.drivers);
          this.updateStats();
          this.renderTable();
        }
      }
    } catch (e) {
      console.warn('Live polling network glitch:', e);
    } finally {
      this.isPollingBusy = false;
    }
  }

  startLivePolling() {
    if (this.pollingInterval) clearInterval(this.pollingInterval);
    this.pollServer();
    this.pollingInterval = setInterval(() => this.pollServer(), 4000);
  }
}

let portal;
document.addEventListener('DOMContentLoaded', () => {
  portal = new DrivingCarePortal();
  window.portal = portal;
});
