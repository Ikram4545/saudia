<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$rawKey = trim($data['key'] ?? '');
$cleanKey = strtoupper($rawKey);
$normalizedKey = preg_replace('/[^A-Z0-9]/', '', $cleanKey);
$deviceId = trim($data['deviceId'] ?? '');
$device = $data['device'] ?? (!empty($deviceId) ? "Android ($deviceId)" : 'Android Mobile');
$client_ip = get_client_ip();

if (empty($cleanKey)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'missing_key',
        'message' => 'Barah-e-karam License Key darj karein.'
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
        if ($driverNormalized === $normalizedKey) {
            $isMatch = true;
        } elseif ($driverNormalized === 'DC' . $normalizedKey) {
            $isMatch = true;
        } elseif ($normalizedKey === 'DC' . $driverNormalized) {
            $isMatch = true;
        }
    }

    if ($isMatch) {
        // Status Check
        if (isset($driver['status']) && $driver['status'] !== 'active') {
            echo json_encode([
                'success' => false,
                'error' => 'key_inactive',
                'message' => 'Aapka license suspend / inactive hai. Admin se rabta karein.'
            ]);
            exit;
        }

        // FIX B: Device Binding Check
        $existingBoundId = trim($driver['boundDeviceId'] ?? '');
        if (!empty($existingBoundId) && !empty($deviceId) && $existingBoundId !== $deviceId) {
            echo json_encode([
                'success' => false,
                'error' => 'device_mismatch',
                'message' => 'Ye key kisi aur phone par band hai.'
            ]);
            exit;
        }

        // First-activation device binding lock
        if (empty($existingBoundId) && !empty($deviceId)) {
            $driver['boundDeviceId'] = $deviceId;
        }

        $driver['online'] = true;
        $driver['lastPing'] = date('c');
        $driver['ip'] = $client_ip;
        $driver['device'] = $device;
        $found = &$driver;
        break;
    }
}

if (!$found) {
    http_response_code(404);
    echo json_encode([
        'success' => false,
        'error' => 'invalid_key',
        'message' => 'License key durust nahi hai ya mojood nahi hai.'
    ]);
    exit;
}

// Log activation
$db['logs'][] = [
    'event' => 'Key Activated / Verified',
    'name' => $found['name'],
    'key' => $found['key'],
    'device' => $device,
    'ip' => $client_ip,
    'timestamp' => date('g:i:s A')
];
if (count($db['logs']) > 50) array_shift($db['logs']);

save_db($db);

echo json_encode([
    'success' => true,
    'driver' => [
        'name' => $found['name'],
        'key' => $found['key'],
        'signedKey' => $found['signedKey'] ?? null,
        'daysLeft' => intval($found['daysLeft'] ?? 30),
        'city' => $found['city'] ?? 'Saudi Arabia',
        'status' => $found['status'] ?? 'active',
        'boundDeviceId' => $found['boundDeviceId'] ?? null,
    ],
    'message' => 'License verified successfully!'
]);
