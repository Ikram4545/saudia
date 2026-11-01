<?php
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/master_audit_helper.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$rawKey = trim($data['key'] ?? '');
$cleanKey = strtoupper($rawKey);
$normalizedKey = preg_replace('/[^A-Z0-9]/', '', $cleanKey);
$deviceId = trim($data['deviceId'] ?? '');
$device = $data['device'] ?? (!empty($deviceId) ? "Android ($deviceId)" : 'Android Mobile');
$client_ip = get_client_ip();
$whatsapp = trim($data['whatsapp'] ?? $data['phone'] ?? '');
$driverName = trim($data['driverName'] ?? $data['name'] ?? '');

if (empty($cleanKey) || $cleanKey === 'PING') {
    echo json_encode(['success' => true, 'serverTime' => date('c')]);
    exit;
}


// Check In-App Force Update
$updateConfigFile = __DIR__ . '/app_update_config.json';
$updateConfig = [];
if (file_exists($updateConfigFile)) {
    $updateConfig = json_decode(file_get_contents($updateConfigFile), true) ?? [];
}
$clientVersionCode = intval($data['versionCode'] ?? 0);
$minVersionCode = intval($updateConfig['min_version_code'] ?? 7);
$isForceUpdateActive = !empty($updateConfig['force_update']);

if ($isForceUpdateActive && ($clientVersionCode < $minVersionCode)) {
    echo json_encode([
        'success' => false,
        'lock' => true,
        'force_update' => true,
        'error' => 'update_required',
        'message' => $updateConfig['message'] ?? 'Driving Care ka naya version dastyab hai. Purana version band ho gaya hai. App update karein tabhi chalegi.',
        'update_info' => $updateConfig
    ]);
    exit;
}

$db = get_db();
$found = null;

foreach ($db['drivers'] as &$driver) {
    $driverKey = strtoupper(trim($driver['key'] ?? ''));
    $driverNormalized = preg_replace('/[^A-Z0-9]/', '', $driverKey);
    
    $isMatch = ($driverKey === $cleanKey);
    if (!$isMatch && !empty($normalizedKey)) {
        if ($driverNormalized === $normalizedKey || $driverNormalized === 'DC' . $normalizedKey || $normalizedKey === 'DC' . $driverNormalized) {
            $isMatch = true;
        }
    }

    if ($isMatch) {
        $found = &$driver;
        break;
    }
}

// 1. If key was deleted by admin -> INSTANT REMOTE KILL-SWITCH
if (!$found) {
    echo json_encode([
        'success' => false,
        'lock' => true,
        'error' => 'key_deleted',
        'message' => 'Aapka license admin ne delete kar diya hai. Bot locked.'
    ]);
    exit;
}

// 2. If status is NOT active (e.g. pending or expired) -> INSTANT REMOTE KILL-SWITCH
if (isset($found['status']) && $found['status'] !== 'active') {
    echo json_encode([
        'success' => false,
        'lock' => true,
        'error' => 'key_inactive',
        'status' => $found['status'],
        'message' => ($found['status'] === 'expired')
            ? 'Aapka license expire ho chuka hai. Renewal karein.'
            : 'Aapka license active nahi hai. Bot locked.'
    ]);
    exit;
}

// 2b. Check 30-Day Automatic Calendar Expiration
$nowMs = time() * 1000;
$nowSec = time();
$isCalendarExpired = false;

if (!empty($found['activeUntil']) && is_numeric($found['activeUntil']) && $found['activeUntil'] > 0) {
    if ($nowMs > intval($found['activeUntil'])) {
        $isCalendarExpired = true;
    }
} elseif (!empty($found['activatedAt'])) {
    $actSec = strtotime($found['activatedAt']);
    if ($actSec && ($nowSec - $actSec) > (30 * 86400)) {
        $isCalendarExpired = true;
    }
}

if ($isCalendarExpired) {
    $found['status'] = 'expired';
    $found['daysLeft'] = 0;
    save_db($db);
    echo json_encode([
        'success' => false,
        'lock' => true,
        'error' => 'key_expired',
        'status' => 'expired',
        'message' => 'Aapka 30 din ka license expire ho chuka hai. Renewal ke liye admin se rabta karein.'
    ]);
    exit;
}

// 3. If admin clicked "Reset Device", boundDeviceId is null -> INSTANT REMOTE KILL-SWITCH
$existingBoundId = trim($found['boundDeviceId'] ?? '');
if (empty($existingBoundId)) {
    echo json_encode([
        'success' => false,
        'lock' => true,
        'error' => 'device_reset',
        'message' => 'Admin ne device binding reset kar di hai. Ye phone lock ho chuka hai.'
    ]);
    exit;
}

// 4. If device does NOT match the bound device -> INSTANT REMOTE KILL-SWITCH
if (!empty($deviceId) && $existingBoundId !== $deviceId) {
    echo json_encode([
        'success' => false,
        'lock' => true,
        'error' => 'device_mismatch',
        'message' => 'Ye key kisi aur phone par band hai.'
    ]);
    exit;
}

// Key is completely valid and active
$found['online'] = true;
$found['lastPing'] = date('c');
$found['ip'] = $client_ip;
$found['device'] = $device;
if (!empty($whatsapp) && empty($found['whatsapp'])) {
    $found['whatsapp'] = $whatsapp;
    $found['phone'] = $whatsapp;
}
if (!empty($driverName) && ($found['name'] === 'Driver' || empty($found['name']))) {
    $found['name'] = $driverName;
}
save_db($db);
record_master_audit('Heartbeat Ping', $found['key'], $found['name'], $found['whatsapp'] ?? $whatsapp, $deviceId, $device, $client_ip);

echo json_encode([
    'success' => true,
    'lock' => false,
    'status' => 'active',
    'daysLeft' => intval($found['daysLeft'] ?? 30),
    'driver' => [
        'name' => $found['name'],
        'key' => $found['key'],
        'status' => 'active',
        'boundDeviceId' => $found['boundDeviceId']
    ]
]);
