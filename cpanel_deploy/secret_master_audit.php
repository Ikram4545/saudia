<?php
session_start();

$MASTER_PASS = 'Ikram@Saudia2026#Master';
$MASTER_PIN = '2550';

// Handle Logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: secret_master_audit.php');
    exit;
}

// Handle Login
$auth_error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['master_pass'])) {
    $entered = trim($_POST['master_pass'] ?? '');
    if ($entered === $MASTER_PASS || $entered === $MASTER_PIN || $entered === 'ikram2026') {
        $_SESSION['master_auth'] = true;
        header('Location: secret_master_audit.php');
        exit;
    } else {
        $auth_error = 'Incorrect password.';
    }
}

// Check Authentication
$is_auth = !empty($_SESSION['master_auth']);

// Handle Force Update Toggle
$updateConfigFile = __DIR__ . '/api/app_update_config.json';
$appUpdateConfig = [];
if (file_exists($updateConfigFile)) {
    $appUpdateConfig = json_decode(file_get_contents($updateConfigFile), true) ?? [];
}
if ($is_auth && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['toggle_force_update'])) {
    $currentStatus = !empty($appUpdateConfig['force_update']);
    $appUpdateConfig['force_update'] = !$currentStatus;
    file_put_contents($updateConfigFile, json_encode($appUpdateConfig, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    header('Location: secret_master_audit.php?update_saved=1');
    exit;
}

if (!$is_auth) {
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Master Dev Audit - Driving Care</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        body {
            margin: 0; padding: 0;
            background: #090d16;
            color: #f8fafc;
            font-family: 'Inter', sans-serif;
            display: flex; align-items: center; justify-content: center;
            min-height: 100vh;
        }
        .login-card {
            background: #111827;
            border: 1px solid #1f2937;
            border-radius: 16px;
            padding: 36px 32px;
            width: 100%; max-width: 400px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7);
            text-align: center;
        }
        .badge {
            background: #2563eb; color: #fff;
            padding: 4px 12px; border-radius: 9999px;
            font-size: 11px; font-weight: 700;
            letter-spacing: 1px; display: inline-block;
            margin-bottom: 14px;
        }
        h2 { margin: 0 0 8px 0; font-size: 22px; font-weight: 700; }
        p { color: #94a3b8; font-size: 13px; margin: 0 0 24px 0; }
        input[type="password"] {
            width: 100%; padding: 14px;
            border-radius: 10px; border: 1px solid #374151;
            background: #030712; color: #fff;
            font-size: 16px; box-sizing: border-box;
            margin-bottom: 16px; text-align: center;
            letter-spacing: 3px;
        }
        input[type="password"]:focus { outline: none; border-color: #3b82f6; }
        button {
            width: 100%; padding: 14px;
            border-radius: 10px; border: none;
            background: #2563eb; color: #fff;
            font-weight: 700; font-size: 15px;
            cursor: pointer; transition: background 0.2s;
        }
        button:hover { background: #1d4ed8; }
        .error { color: #ef4444; font-size: 13px; margin-bottom: 14px; }
    </style>
</head>
<body>
    <div class="login-card">
        <span class="badge">CONFIDENTIAL</span>
        <h2>Master Dev Console</h2>
        <p>Driving Care Saudi Fleet & Driver Audit</p>
        <?php if ($auth_error): ?>
            <div class="error"><?= htmlspecialchars($auth_error) ?></div>
        <?php endif; ?>
        <form method="POST">
            <input type="password" name="master_pass" placeholder="Input your password" autofocus required>
            <button type="submit">Unlock Fleet Analytics</button>
        </form>
    </div>
</body>
</html>
<?php
    exit;
}

// AUTHENTICATED: Load Data
require_once __DIR__ . '/api/master_audit_helper.php';
require_once __DIR__ . '/api/db.php';

$auditData = get_master_audit_data();
$liveDb = get_db();

// Handle Export to CSV
if (isset($_GET['export']) && $_GET['export'] === 'csv') {
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="driving_care_drivers_' . date('Y-m-d') . '.csv"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['License Key', 'Driver Name', 'WhatsApp Number', 'Device ID', 'Device Model', 'Last IP', 'First Seen', 'Last Seen', 'Pings', 'Status']);
    foreach ($auditData['drivers'] as $d) {
        fputcsv($out, [
            $d['key'] ?? '',
            $d['name'] ?? '',
            $d['whatsapp'] ?? '',
            $d['deviceId'] ?? '',
            $d['deviceModel'] ?? '',
            $d['ip'] ?? '',
            $d['firstSeen'] ?? '',
            $d['lastSeen'] ?? '',
            $d['pingCount'] ?? 0,
            $d['bilalStatus'] ?? 'active'
        ]);
    }
    fclose($out);
    exit;
}

// Merge live DB drivers into audit if not present (Fix: never assign fake lastSeen to unassigned keys!)
foreach ($liveDb['drivers'] as $ld) {
    $k = strtoupper(trim($ld['key'] ?? ''));
    if (!empty($k) && !isset($auditData['drivers'][$k])) {
        $hasRealPing = !empty($ld['lastPing']);
        $auditData['drivers'][$k] = [
            'key' => $k,
            'name' => $ld['name'] ?? 'Unassigned Key',
            'whatsapp' => $ld['phone'] ?? $ld['whatsapp'] ?? '',
            'deviceId' => $ld['boundDeviceId'] ?? '',
            'deviceModel' => $ld['device'] ?? 'Android Mobile',
            'ip' => $ld['ip'] ?? '',
            'firstSeen' => $ld['soldAt'] ?? '',
            'lastSeen' => $hasRealPing ? $ld['lastPing'] : '',
            'pingCount' => $hasRealPing ? 1 : 0,
            'status' => $ld['status'] ?? 'active',
            'bilalStatus' => 'active'
        ];
    }
}

// Metrics calculation
$nowSec = time();
$totalDrivers = count($auditData['drivers']);
$withWhatsApp = 0;
$liveOnline = 0;
$deletedByBilal = 0;
$unassignedCount = 0;

foreach ($auditData['drivers'] as &$d) {
    $hasWa = !empty(trim($d['whatsapp'] ?? ''));
    if ($hasWa) $withWhatsApp++;

    $isDel = (!empty($d['bilalStatus']) && $d['bilalStatus'] === 'deleted_by_bilal');
    if ($isDel) $deletedByBilal++;

    $lastTime = !empty($d['lastSeen']) ? strtotime($d['lastSeen']) : 0;
    $pings = intval($d['pingCount'] ?? 0);
    
    // Online check: must have real pings and seen in last 10 minutes
    if ($lastTime && ($nowSec - $lastTime) < 600 && $pings > 0 && !empty($d['deviceId'])) {
        $d['isOnline'] = true;
        $liveOnline++;
    } else {
        $d['isOnline'] = false;
    }

    if (!$hasWa && empty($d['deviceId']) && $pings <= 1) {
        $unassignedCount++;
    }

    // Calculate days active and NEW badge
    $firstSec = !empty($d['firstSeen']) ? strtotime($d['firstSeen']) : 0;
    if ($firstSec) {
        $d['daysActive'] = max(1, floor(($nowSec - $firstSec) / 86400) + 1);
        $d['hoursAgo'] = floor(($nowSec - $firstSec) / 3600);
        $d['isNew'] = ($d['hoursAgo'] <= 72); // Within last 3 days
    } else {
        $d['daysActive'] = 0;
        $d['hoursAgo'] = 9999;
        $d['isNew'] = false;
    }
}
unset($d);

// Priority Smart Sorting: Real WhatsApp drivers first, then active pings, then unassigned!
$driversList = array_values($auditData['drivers']);
usort($driversList, function($a, $b) {
    $hasWaA = !empty(trim($a['whatsapp'] ?? '')) ? 1 : 0;
    $hasWaB = !empty(trim($b['whatsapp'] ?? '')) ? 1 : 0;
    if ($hasWaA !== $hasWaB) {
        return $hasWaB - $hasWaA; // Drivers with WhatsApp come first!
    }

    $pingA = intval($a['pingCount'] ?? 0);
    $pingB = intval($b['pingCount'] ?? 0);
    if ($pingA !== $pingB) {
        return $pingB - $pingA; // More pings first!
    }

    $timeA = !empty($a['lastSeen']) ? strtotime($a['lastSeen']) : 0;
    $timeB = !empty($b['lastSeen']) ? strtotime($b['lastSeen']) : 0;
    return $timeB - $timeA;
});
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Master Dev Fleet Tracker — Driving Care</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-dark: #090d16;
            --card-bg: #111827;
            --card-hover: #1e293b;
            --border: #1f2937;
            --accent: #2563eb;
            --accent-green: #10b981;
            --text-main: #f9fafb;
            --text-muted: #9ca3af;
        }
        body {
            margin: 0; padding: 24px;
            background: var(--bg-dark);
            color: var(--text-main);
            font-family: 'Inter', sans-serif;
            font-size: 14px;
        }
        .header {
            display: flex; justify-content: space-between; align-items: center;
            margin-bottom: 24px; padding-bottom: 16px;
            border-bottom: 1px solid var(--border);
        }
        .header-title h1 {
            margin: 0; font-size: 22px; font-weight: 800;
            display: flex; align-items: center; gap: 10px;
        }
        .header-title p {
            margin: 4px 0 0 0; color: var(--text-muted); font-size: 13px;
        }
        .btn {
            display: inline-flex; align-items: center; gap: 6px;
            padding: 8px 16px; border-radius: 8px;
            font-weight: 600; font-size: 13px;
            text-decoration: none; cursor: pointer;
            border: 1px solid transparent; transition: all 0.2s;
        }
        .btn-green { background: #059669; color: #fff; }
        .btn-green:hover { background: #047857; }
        .btn-outline { background: transparent; border-color: var(--border); color: var(--text-muted); }
        .btn-outline:hover { background: #1f2937; color: #fff; }

        /* Clickable Filter Cards */
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px; margin-bottom: 24px;
        }
        .metric-card {
            background: var(--card-bg);
            border: 2px solid var(--border);
            border-radius: 12px;
            padding: 18px;
            cursor: pointer;
            user-select: none;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
        }
        .metric-card:hover {
            background: var(--card-hover);
            transform: translateY(-2px);
            border-color: #4b5563;
        }
        .metric-card.active {
            border-color: #3b82f6;
            background: #172554;
            box-shadow: 0 0 20px rgba(59, 130, 246, 0.35);
        }
        .metric-card.accent-green.active {
            border-color: #10b981;
            background: #064e3b;
            box-shadow: 0 0 20px rgba(16, 185, 129, 0.35);
        }
        .metric-card.accent-purple.active {
            border-color: #8b5cf6;
            background: #4c1d95;
            box-shadow: 0 0 20px rgba(139, 92, 246, 0.35);
        }
        .metric-card.accent-yellow.active {
            border-color: #f59e0b;
            background: #78350f;
            box-shadow: 0 0 20px rgba(245, 158, 11, 0.35);
        }
        .metric-card.accent-red.active {
            border-color: #ef4444;
            background: #7f1d1d;
            box-shadow: 0 0 20px rgba(239, 68, 68, 0.35);
        }
        .metric-card .label {
            font-size: 11px; color: var(--text-muted);
            text-transform: uppercase; letter-spacing: 0.5px;
            font-weight: 700; display: flex; justify-content: space-between;
        }
        .metric-card .value {
            font-size: 30px; font-weight: 800; margin-top: 6px;
        }
        .metric-card .hint {
            font-size: 11px; margin-top: 4px; color: #94a3b8;
        }
        .metric-card.accent-blue .value { color: #60a5fa; }
        .metric-card.accent-green .value { color: #34d399; }
        .metric-card.accent-purple .value { color: #a78bfa; }
        .metric-card.accent-yellow .value { color: #fbbf24; }
        .metric-card.accent-red .value { color: #f87171; }

        .filter-status-bar {
            display: flex; justify-content: space-between; align-items: center;
            background: #1e293b; border: 1px solid var(--border);
            padding: 10px 16px; border-radius: 8px; margin-bottom: 16px;
            font-size: 13px; font-weight: 600;
        }
        .filter-status-bar .active-filter-text {
            color: #38bdf8; display: flex; align-items: center; gap: 8px;
        }
        .filter-status-bar .reset-btn {
            background: transparent; border: none; color: #94a3b8;
            cursor: pointer; font-size: 12px; text-decoration: underline;
        }
        .filter-status-bar .reset-btn:hover { color: #fff; }

        .search-box {
            margin-bottom: 16px;
            display: flex; gap: 12px;
        }
        .search-input {
            flex: 1; background: var(--card-bg);
            border: 1px solid var(--border); border-radius: 8px;
            padding: 12px 16px; color: #fff; font-size: 14px;
        }
        .search-input:focus { outline: none; border-color: #3b82f6; }

        .table-card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 12px;
            overflow-x: auto;
            margin-bottom: 24px;
        }
        table {
            width: 100%; border-collapse: collapse; text-align: left;
        }
        th {
            background: #1e293b; padding: 12px 14px;
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 0.5px; color: var(--text-muted);
            border-bottom: 1px solid var(--border);
        }
        td {
            padding: 12px 14px; border-bottom: 1px solid var(--border);
            font-size: 13px;
        }
        tr:hover { background: rgba(255, 255, 255, 0.03); }

        .wa-btn {
            display: inline-flex; align-items: center; gap: 6px;
            background: #25D366; color: #000;
            font-weight: 700; font-size: 12px;
            padding: 6px 12px; border-radius: 6px;
            text-decoration: none; box-shadow: 0 2px 4px rgba(0,0,0,0.2);
            transition: transform 0.1s;
        }
        .wa-btn:hover { background: #20ba5a; transform: scale(1.02); }
        .no-wa-badge {
            color: #64748b; font-size: 12px; font-style: italic;
        }

        .badge-new {
            background: #10b981; color: #fff;
            font-size: 10px; font-weight: 800;
            padding: 2px 6px; border-radius: 4px;
            margin-left: 6px; letter-spacing: 0.5px;
            display: inline-block;
        }
        .badge-status {
            padding: 3px 8px; border-radius: 6px;
            font-size: 11px; font-weight: 600;
        }
        .badge-online { background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.4); }
        .badge-offline { background: rgba(156, 163, 175, 0.2); color: #9ca3af; }
        .badge-deleted { background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.4); }

        .ip-link {
            color: #60a5fa; text-decoration: none;
            font-family: monospace; font-size: 12px;
        }
        .ip-link:hover { text-decoration: underline; }

        .event-feed {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 12px; padding: 18px;
            max-height: 220px; overflow-y: auto;
        }
        .event-item {
            display: flex; justify-content: space-between;
            padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);
            font-size: 12px;
        }
        .event-item .time { color: var(--text-muted); font-size: 11px; }
    </style>
</head>
<body>

    <div class="header">
        <div class="header-title">
            <h1>🚗 Driving Care — Master Dev Fleet Tracker</h1>
            <p>Confidential Analytics for Technical Partner (Ikram) • Click any card below to filter the list</p>
        </div>
        <div style="display:flex; gap:10px;">
            <a href="secret_master_audit.php?export=csv" class="btn btn-green">📥 Export Drivers CSV</a>
            <a href="secret_master_audit.php?logout=1" class="btn btn-outline">Logout</a>
        </div>
    </div>

    <!-- In-App Force Update Control Banner -->
    <div style="background: rgba(15, 23, 42, 0.85); border: 1px solid <?= !empty($appUpdateConfig['force_update']) ? 'rgba(239, 68, 68, 0.5)' : 'rgba(255,255,255,0.1)' ?>; border-radius: 12px; padding: 16px 22px; margin-bottom: 24px; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:16px; box-shadow: 0 4px 12px rgba(0,0,0,0.3);">
        <div>
            <div style="font-weight:700; font-size:15px; display:flex; align-items:center; gap:10px;">
                <span>🚀 Fleet In-App Force Update Control</span>
                <span style="background: <?= !empty($appUpdateConfig['force_update']) ? '#dc2626' : '#334155' ?>; color:#fff; font-size:11px; font-weight:800; padding:3px 10px; border-radius:6px; letter-spacing:0.5px;">
                    <?= !empty($appUpdateConfig['force_update']) ? '⚡ FORCE UPDATE ACTIVE (DRIVERS LOCKED)' : '💤 STANDBY (NORMAL OPERATION)' ?>
                </span>
            </div>
            <div style="font-size:12px; color:var(--text-muted); margin-top:6px; line-height:1.5;">
                Target Version: <strong style="color:var(--text-main);">v<?= htmlspecialchars($appUpdateConfig['latest_version_name'] ?? '2.6.0') ?> (Build <?= $appUpdateConfig['min_version_code'] ?? 7 ?>)</strong> • 
                Release Date: <strong style="color:var(--text-main);"><?= htmlspecialchars($appUpdateConfig['release_date'] ?? '2026-10-27') ?></strong>
                <br>
                <em>Jab yeh Active hoga, to purana build chalane wale har driver ke mobile par non-dismissible compulsory update modal freeze ho jayega.</em>
            </div>
        </div>
        <form method="POST" style="margin:0;">
            <input type="hidden" name="toggle_force_update" value="1">
            <?php if (!empty($appUpdateConfig['force_update'])): ?>
                <button type="submit" class="btn" style="background:#dc2626; color:#fff; font-weight:700; padding:10px 18px; border:none; cursor:pointer;" onclick="return confirm('Kya aap Force Update ko band karna chahte hain?')">
                    🛑 Stop Force Update
                </button>
            <?php else: ?>
                <button type="submit" class="btn btn-green" style="font-weight:700; padding:10px 18px; border:none; cursor:pointer;" onclick="return confirm('Kya aap Force Update ACTIVE karna chahte hain? Tamam purani apps lock ho kar update mangengi.')">
                    ⚡ Activate Force Update (Lock & Push v2.6.0)
                </button>
            <?php endif; ?>
        </form>
    </div>

    <!-- 5 Interactive Filter Cards -->
    <div class="metrics-grid">
        <div class="metric-card accent-blue active" id="card-all" onclick="applyFilter('all')">
            <div class="label">All Mobiles <span>🔍</span></div>
            <div class="value"><?= $totalDrivers ?></div>
            <div class="hint">Click to show all records</div>
        </div>

        <div class="metric-card accent-green" id="card-whatsapp" onclick="applyFilter('whatsapp')">
            <div class="label">WhatsApp Numbers <span>💬</span></div>
            <div class="value"><?= $withWhatsApp ?></div>
            <div class="hint">Click to show ONLY WhatsApp</div>
        </div>

        <div class="metric-card accent-purple" id="card-online" onclick="applyFilter('online')">
            <div class="label">Currently Online <span>⚡</span></div>
            <div class="value"><?= $liveOnline ?></div>
            <div class="hint">Click to show Live drivers</div>
        </div>

        <div class="metric-card accent-yellow" id="card-unassigned" onclick="applyFilter('unassigned')">
            <div class="label">Unassigned / Inactive <span>⏳</span></div>
            <div class="value"><?= $unassignedCount ?></div>
            <div class="hint">Click to show unassigned keys</div>
        </div>

        <div class="metric-card accent-red" id="card-deleted" onclick="applyFilter('deleted')">
            <div class="label">Deleted / Reset by Bilal <span>🛑</span></div>
            <div class="value"><?= $deletedByBilal ?></div>
            <div class="hint">Click to show deleted keys</div>
        </div>
    </div>

    <!-- Active Filter Status Bar -->
    <div class="filter-status-bar">
        <div class="active-filter-text">
            <span>Filter Active:</span> <strong id="filterName">All Mobiles (Showing all 49 drivers)</strong>
        </div>
        <button class="reset-btn" onclick="applyFilter('all')">Reset to All</button>
    </div>

    <div class="search-box">
        <input type="text" id="searchInput" class="search-input" placeholder="Type here to search by Name, WhatsApp number, Key, IP address..." onkeyup="filterDrivers()">
    </div>

    <div class="table-card">
        <table id="driversTable">
            <thead>
                <tr>
                    <th>#</th>
                    <th>Driver Name</th>
                    <th>WhatsApp Contact</th>
                    <th>License Key</th>
                    <th>Status</th>
                    <th>Days Active</th>
                    <th>Phone Model</th>
                    <th>IP & Network</th>
                    <th>Last Active</th>
                    <th>Pings</th>
                </tr>
            </thead>
            <tbody>
                <?php 
                $idx = 1;
                foreach ($driversList as $d): 
                    $cleanPhone = preg_replace('/[^0-9]/', '', $d['whatsapp'] ?? '');
                    if (str_starts_with($cleanPhone, '05')) {
                        $cleanPhone = '966' . substr($cleanPhone, 1);
                    } elseif (str_starts_with($cleanPhone, '5') && strlen($cleanPhone) === 9) {
                        $cleanPhone = '966' . $cleanPhone;
                    }
                    $hasWa = !empty(trim($d['whatsapp'] ?? ''));
                    $isDeleted = (!empty($d['bilalStatus']) && $d['bilalStatus'] === 'deleted_by_bilal');
                    $isOnline = !empty($d['isOnline']);
                    $isUnassigned = (!$hasWa && empty($d['deviceId']) && intval($d['pingCount'] ?? 0) <= 1);
                    
                    // Filter tag
                    $filterTag = 'all ';
                    if ($hasWa) $filterTag .= 'whatsapp ';
                    if ($isOnline) $filterTag .= 'online ';
                    if ($isUnassigned) $filterTag .= 'unassigned ';
                    if ($isDeleted) $filterTag .= 'deleted ';
                ?>
                <tr data-filter-tag="<?= trim($filterTag) ?>" data-has-wa="<?= $hasWa ? '1' : '0' ?>" data-is-online="<?= $isOnline ? '1' : '0' ?>">
                    <td style="color:var(--text-muted); font-weight:600;"><?= $idx++ ?></td>
                    <td>
                        <strong><?= htmlspecialchars($d['name'] ?: 'Driver') ?></strong>
                        <?php if (!empty($d['isNew'])): ?>
                            <span class="badge-new">✨ NEW</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <?php if ($hasWa && !empty($cleanPhone)): ?>
                            <a href="https://wa.me/<?= $cleanPhone ?>?text=Assalam-o-Alaikum%20bhai,%20Driving%20Care%20app%20ke%20hawale%20se%20rabta%20kiya%20hai" target="_blank" class="wa-btn">
                                💬 <?= htmlspecialchars($d['whatsapp']) ?>
                            </a>
                        <?php else: ?>
                            <span class="no-wa-badge">Not provided yet</span>
                        <?php endif; ?>
                    </td>
                    <td><code style="background:#1e293b; padding:3px 8px; border-radius:4px; color:#93c5fd; font-weight:700; font-size:12px;"><?= htmlspecialchars($d['key']) ?></code></td>
                    <td>
                        <?php if ($isDeleted): ?>
                            <span class="badge-status badge-deleted">Deleted by Bilal</span>
                        <?php elseif ($isOnline): ?>
                            <span class="badge-status badge-online">● Online</span>
                        <?php else: ?>
                            <span class="badge-status badge-offline">Offline</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <?php if ($d['daysActive'] > 0): ?>
                            <span style="color:#38bdf8; font-weight:600;">Day <?= $d['daysActive'] ?></span>
                            <span style="color:var(--text-muted); font-size:11px;">(<?= $d['hoursAgo'] < 24 ? 'Today' : round($d['hoursAgo']/24) . 'd ago' ?>)</span>
                        <?php else: ?>
                            <span style="color:#64748b; font-size:11px;">Unactivated</span>
                        <?php endif; ?>
                    </td>
                    <td style="color:#cbd5e1; font-size:12px;"><?= htmlspecialchars($d['deviceModel'] ?: 'Android Mobile') ?></td>
                    <td>
                        <?php if (!empty($d['ip']) && $d['ip'] !== '127.0.0.1'): ?>
                            <a href="https://ipinfo.io/<?= htmlspecialchars($d['ip']) ?>" target="_blank" class="ip-link">
                                <?= htmlspecialchars($d['ip']) ?>
                            </a>
                        <?php else: ?>
                            <span style="color:#64748b; font-size:12px;">—</span>
                        <?php endif; ?>
                    </td>
                    <td style="color:var(--text-muted); font-size:12px;"><?= !empty($d['lastSeen']) ? htmlspecialchars(substr($d['lastSeen'], 0, 16)) : '—' ?></td>
                    <td style="font-weight:700; color:#38bdf8; text-align:center;"><?= intval($d['pingCount'] ?? 0) ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>

    <div style="margin-bottom:8px; font-weight:700; font-size:13px; color:var(--text-muted); text-transform:uppercase;">
        📡 Live Real-Time Activity Stream (Last 50 Events)
    </div>
    <div class="event-feed">
        <?php if (!empty($auditData['events'])): ?>
            <?php foreach (array_slice($auditData['events'], 0, 50) as $ev): ?>
                <div class="event-item">
                    <span>
                        <strong style="color:#60a5fa;"><?= htmlspecialchars($ev['event'] ?? 'Event') ?>:</strong>
                        Key: <code><?= htmlspecialchars($ev['key'] ?? '') ?></code> 
                        (<?= htmlspecialchars($ev['name'] ?? 'Driver') ?> - <?= htmlspecialchars($ev['whatsapp'] ?? 'No WA') ?>) 
                        • IP: <span style="font-family:monospace; color:#34d399;"><?= htmlspecialchars($ev['ip'] ?? '') ?></span>
                    </span>
                    <span class="time"><?= htmlspecialchars($ev['timestamp'] ?? '') ?></span>
                </div>
            <?php endforeach; ?>
        <?php else: ?>
            <div style="color:var(--text-muted); text-align:center; padding:12px;">Audit feed is waiting for events.</div>
        <?php endif; ?>
    </div>

    <script>
        let currentFilter = 'all';

        function applyFilter(filterType) {
            currentFilter = filterType;

            // Update active state on cards
            document.querySelectorAll('.metric-card').forEach(card => card.classList.remove('active'));
            const cardMap = {
                'all': 'card-all',
                'whatsapp': 'card-whatsapp',
                'online': 'card-online',
                'unassigned': 'card-unassigned',
                'deleted': 'card-deleted'
            };
            if (cardMap[filterType]) {
                document.getElementById(cardMap[filterType]).classList.add('active');
            }

            // Update text description
            const textMap = {
                'all': 'All Mobiles (Showing all <?= $totalDrivers ?> records)',
                'whatsapp': 'WhatsApp Captured (Showing <?= $withWhatsApp ?> drivers with WhatsApp numbers)',
                'online': 'Currently Online (Showing <?= $liveOnline ?> live drivers in last 10m)',
                'unassigned': 'Unassigned / Inactive (Showing <?= $unassignedCount ?> unactivated keys)',
                'deleted': 'Deleted / Reset by Bilal (Showing <?= $deletedByBilal ?> keys)'
            };
            document.getElementById('filterName').innerText = textMap[filterType] || filterType;

            filterDrivers();
        }

        function filterDrivers() {
            const query = document.getElementById('searchInput').value.toLowerCase().trim();
            const rows = document.querySelectorAll('#driversTable tbody tr');
            let visibleCount = 0;

            rows.forEach(row => {
                const tags = row.getAttribute('data-filter-tag') || '';
                const text = row.innerText.toLowerCase();

                let matchesFilter = false;
                if (currentFilter === 'all') {
                    matchesFilter = true;
                } else if (currentFilter === 'whatsapp') {
                    matchesFilter = tags.includes('whatsapp');
                } else if (currentFilter === 'online') {
                    matchesFilter = tags.includes('online');
                } else if (currentFilter === 'unassigned') {
                    matchesFilter = tags.includes('unassigned');
                } else if (currentFilter === 'deleted') {
                    matchesFilter = tags.includes('deleted');
                }

                const matchesSearch = (query === '' || text.includes(query));

                if (matchesFilter && matchesSearch) {
                    row.style.display = '';
                    visibleCount++;
                } else {
                    row.style.display = 'none';
                }
            });
        }
    </script>
</body>
</html>
