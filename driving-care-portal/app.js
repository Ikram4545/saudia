// Driving Care Portal - Core Application Logic
// Designed for Bilal (Owner) & Ikram (Technical Partner - 15% Share)

const STORAGE_KEY = 'driving_care_drivers_v1';
const SAR_TO_PKR_RATE = 74.5; // Approximate exchange rate

// Pre-seeded sample drivers for demonstration
const DEFAULT_DRIVERS = [
  {
    id: 'd1',
    name: 'Tariq Al-Harbi',
    phone: '+966 50 491 8821',
    city: 'Riyadh',
    key: 'DC-8921',
    feeSAR: 150,
    status: 'active', // active, pending, expired
    activatedAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(), // 5 days ago
    expiresAt: new Date(Date.now() + 25 * 24 * 60 * 60 * 1000).toISOString(), // 25 days left
  },
  {
    id: 'd2',
    name: 'Fahad Saeed',
    phone: '+966 55 128 9034',
    city: 'Jeddah',
    key: 'DC-7740',
    feeSAR: 150,
    status: 'active',
    activatedAt: new Date(Date.now() - 28 * 24 * 60 * 60 * 1000).toISOString(), // 28 days ago
    expiresAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(), // 2 days left (Expiring soon)
  },
  {
    id: 'd3',
    name: 'Muhammad Asif',
    phone: '+966 53 874 1120',
    city: 'Riyadh',
    key: 'asif30',
    feeSAR: 150,
    status: 'expired',
    activatedAt: new Date(Date.now() - 35 * 24 * 60 * 60 * 1000).toISOString(),
    expiresAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(), // Expired 5 days ago
  },
  {
    id: 'd4',
    name: 'Abdulrahman Al-Dosari',
    phone: '+966 56 312 9945',
    city: 'Dammam',
    key: 'DC-4412',
    feeSAR: 150,
    status: 'pending',
    activatedAt: null,
    expiresAt: null
  }
];

class DrivingCarePortal {
  constructor() {
    this.drivers = this.loadDrivers();
    this.activeFilter = 'all';
    this.searchQuery = '';
    this.initElements();
    this.bindEvents();
    this.render();
    this.startLivePolling();
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
    this.driverFeeInput = document.getElementById('driverFee');
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

  openAddModal() {
    this.driverForm.reset();
    this.generateRandomKey();
    this.driverFeeInput.value = '150';
    this.driverModal.style.display = 'flex';
  }

  closeAddModal() {
    this.driverModal.style.display = 'none';
  }

  handleSaveDriver() {
    const name = this.driverNameInput.value.trim();
    const phone = this.driverPhoneInput.value.trim();
    const city = this.driverCityInput.value;
    const key = this.driverKeyInput.value.trim();
    const feeSAR = parseFloat(this.driverFeeInput.value) || 150;
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
      name,
      phone,
      city,
      key,
      feeSAR,
      status: initialStatus,
      activatedAt,
      expiresAt
    };

    this.drivers.unshift(newDriver);
    this.saveDrivers(this.drivers);
    this.closeAddModal();
    this.render();
    this.showToast(`Driver ${name} created with 30-day key: ${key}!`);
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
    }
  }

  // Generate WhatsApp Message for Driver
  copyDriverWhatsApp(id) {
    const d = this.drivers.find(x => x.id === id);
    if (!d) return;

    const expDateStr = d.expiresAt ? new Date(d.expiresAt).toLocaleDateString('en-GB') : 'Upon Activation';
    const message = 
`Salam ${d.name} Bhai! 🚗
Aap ki "Driving Care" Auto Bot App ki key ready hai:

🔑 *License Key:* ${d.key}
📅 *Validity:* 30 Days (Valid until: ${expDateStr})
⚡ *Supported Apps:* Jeeny, Uber, Bolt

*How to Activate:*
1. Driving Care app open karein.
2. Apna user key daalein: *${d.key}*
3. "Activate App" par click karein.
4. Settings mein Min Price, Max Price aur Area select karke Bot ON kar lein!

Support WhatsApp: Bilal (+966 53 419 9549)`;

    navigator.clipboard.writeText(message).then(() => {
      this.showToast(`WhatsApp message copied for ${d.name}!`);
    }).catch(() => {
      prompt('Copy this message for driver:', message);
    });
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

    this.drivers.forEach(d => {
      if (d.status === 'pending') {
        pending++;
      } else {
        const exp = d.expiresAt ? new Date(d.expiresAt) : null;
        if (exp && exp > now) {
          active++;
          totalRevSAR += (d.feeSAR || 150);
          const daysLeft = (exp - now) / (24 * 60 * 60 * 1000);
          if (daysLeft <= 3) expiring++;
        } else {
          expired++;
        }
      }
    });

    // Financial calculation (Ikram's 15% Share)
    const ikramShareSAR = Math.round(totalRevSAR * 0.15);
    const ikramSharePKR = Math.round(ikramShareSAR * SAR_TO_PKR_RATE);

    // Update DOM stats
    this.totalDriversCount.textContent = total;
    this.activeLicensesCount.textContent = active;
    this.expiredLicensesCount.textContent = `${expired + pending}`;
    this.totalRevenueSAR.innerHTML = `${totalRevSAR.toLocaleString()} <span class="currency">SAR</span>`;
    this.ikramShareText.textContent = `${ikramShareSAR.toLocaleString()} SAR (~${ikramSharePKR.toLocaleString()} PKR)`;

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
                  <a href="${waUrl}" target="_blank" class="wa-link" title="Open WhatsApp">💬 Chat</a>
                </div>
              </div>
            </div>
          </td>
          <td><strong>${d.city}</strong></td>
          <td>
            <span class="key-code" onclick="portal.copyKey('${d.key}')" title="Click to copy key">
              🔑 ${d.key}
            </span>
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
          <td>
            <strong>${d.feeSAR} SAR</strong>
            <div style="font-size: 0.72rem; color: var(--accent-emerald);">Dev: ${(d.feeSAR * 0.15).toFixed(0)} SAR</div>
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
      try {
        const res = await fetch('/api/admin/drivers');
        if (res.ok) {
          const data = await res.json();
          if (data && data.drivers) {
            this.drivers = data.drivers.map((d, index) => ({
              id: 'd_' + index,
              name: d.name,
              phone: d.phone,
              city: d.city,
              key: d.key,
              feeSAR: 150,
              status: d.status,
              online: d.online,
              device: d.device || 'Android Phone',
              ip: d.ip || '-',
              daysLeft: d.daysLeft || 30,
              activatedAt: new Date().toISOString(),
              expiresAt: new Date(Date.now() + (d.daysLeft || 30) * 24 * 60 * 60 * 1000).toISOString()
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
