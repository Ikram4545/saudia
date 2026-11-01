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

// Always return HTTP 200 with clear JSON so mobile carriers (STC, Mobily) do not drop the payload
if (empty($cleanKey)) {
    http_response_code(200);
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
            if ($driver['status'] === 'pending') {
                // Record activation request details from driver's phone
                $driver['requestedDeviceId'] = $deviceId;
                $driver['requestedDevice'] = $device;
                $driver['requestedAt'] = date('Y-m-d H:i:s');
                $driver['ip'] = $client_ip;
                if (!empty($whatsapp)) $driver['whatsapp'] = $whatsapp;
                if (!empty($driverName) && $driverName !== 'Driver') $driver['name'] = $driverName;
                record_master_audit('Activation Request (Pending)', $driver['key'], $driver['name'], $whatsapp, $deviceId, $device, $client_ip);
                
                $db['logs'][] = [
                    'event' => "Activation Request: Key {$driver['key']} (Device: {$deviceId})",
                    'name' => $driver['name'] ?? 'Driver',
                    'key' => $driver['key'],
                    'device' => $device,
                    'ip' => $client_ip,
                    'timestamp' => date('g:i:s A')
                ];
                if (count($db['logs']) > 50) array_shift($db['logs']);
                save_db($db);

                http_response_code(200);
                echo json_encode([
                    'success' => false,
                    'error' => 'pending_approval',
                    'key' => $driver['key'],
                    'deviceId' => $deviceId,
                    'supportPhone' => '+966 53 419 9549',
                    'message' => 'Aapki activation request bhej di gayi hai! Admin se WhatsApp par approve karwayein.'
                ]);
                exit;
            } elseif ($driver['status'] === 'expired') {
                http_response_code(200);
                echo json_encode([
                    'success' => false,
                    'error' => 'key_expired',
                    'message' => 'Aapka 30 din ka license expire ho chuka hai. Renewal ke liye admin se rabta karein.'
                ]);
                exit;
            } else {
                http_response_code(200);
                echo json_encode([
                    'success' => false,
                    'error' => 'key_inactive',
                    'message' => 'Aapka license suspend / inactive hai. Admin se rabta karein.'
                ]);
                exit;
            }
        }

        // Check 30-Day Automatic Calendar Expiration
        $nowMs = time() * 1000;
        $nowSec = time();
        $isCalendarExpired = false;

        if (!empty($driver['activeUntil']) && is_numeric($driver['activeUntil']) && $driver['activeUntil'] > 0) {
            if ($nowMs > intval($driver['activeUntil'])) {
                $isCalendarExpired = true;
            }
        } elseif (!empty($driver['activatedAt'])) {
            $actSec = strtotime($driver['activatedAt']);
            if ($actSec && ($nowSec - $actSec) > (30 * 86400)) {
                $isCalendarExpired = true;
            }
        }

        if ($isCalendarExpired) {
            $driver['status'] = 'expired';
            $driver['daysLeft'] = 0;
            save_db($db);
            http_response_code(200);
            echo json_encode([
                'success' => false,
                'error' => 'key_expired',
                'message' => 'Aapka 30 din ka license expire ho chuka hai. Renewal ke liye admin se rabta karein.'
            ]);
            exit;
        }

        // Device Binding Check
        $existingBoundId = trim($driver['boundDeviceId'] ?? '');
        if (!empty($existingBoundId) && !empty($deviceId) && $existingBoundId !== $deviceId) {
            http_response_code(200);
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
                if (!empty($whatsapp)) $driver['whatsapp'] = $whatsapp;
                if (!empty($driverName) && $driverName !== 'Driver') $driver['name'] = $driverName;
                record_master_audit('Activation Request (Pending)', $driver['key'], $driver['name'], $whatsapp, $deviceId, $device, $client_ip);
        $driver['device'] = $device;
        if (!empty($whatsapp)) {
            $driver['whatsapp'] = $whatsapp;
            $driver['phone'] = $whatsapp;
        }
        if (!empty($driverName) && $driverName !== 'Driver') {
            $driver['name'] = $driverName;
        }
        $found = &$driver;
        record_master_audit('Key Activated / Verified', $found['key'], $found['name'], $found['whatsapp'] ?? $whatsapp, $deviceId, $device, $client_ip);
        break;
    }
}

if (!$found) {
    http_response_code(200);
    echo json_encode([
        'success' => false,
        'error' => 'invalid_key',
        'message' => "License key '$rawKey' database mein nahi mili. Baraye meherbani sahi key check karein."
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

http_response_code(200);
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
