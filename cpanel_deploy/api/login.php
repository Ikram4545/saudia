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

// Strict Name Validation
if (empty($driverName) || mb_strlen($driverName) < 3 || strcasecmp($driverName, 'driver') === 0) {
    http_response_code(200);
    echo json_encode([
        'success' => false,
        'error' => 'invalid_name',
        'message' => 'Barah-e-karam apna mukammal asli naam darj karein (kam az kam 3 haroof).'
    ]);
    exit;
}

// Duplicate Name Check across existing drivers
$nameLower = mb_strtolower(trim($driverName));
foreach ($db['drivers'] as $existingDriver) {
    $existingKey = strtoupper(trim($existingDriver['key'] ?? ''));
    if ($existingKey !== $cleanKey && !empty($existingDriver['name']) && strcasecmp($existingDriver['name'], 'driver') !== 0 && strcasecmp($existingDriver['name'], 'new saudi driver') !== 0) {
        if (mb_strtolower(trim($existingDriver['name'])) === $nameLower) {
            http_response_code(200);
            echo json_encode([
                'success' => false,
                'error' => 'duplicate_name',
                'message' => "Yeh naam '$driverName' pehle se registered hai. Barah-e-karam apna mukammal naam (e.g. '$driverName Khan') darj karein taake duplicate na ho."
            ]);
            exit;
        }
    }
}

// Strict WhatsApp / Phone Validation (Block Dummy Numbers & Repetitive Patterns)
$digitsOnly = preg_replace('/[^0-9]/', '', $whatsapp);
$isDummy = false;

if (strlen($digitsOnly) < 8) {
    $isDummy = true;
} elseif (count(array_unique(str_split($digitsOnly))) <= 1) {
    // All same digits, e.g. 00000000, 11111111
    $isDummy = true;
} else {
    $commonDummies = ['12345678', '123456789', '98765432', '987654321', '11223344', '112233444', '123123123', '01234567'];
    foreach ($commonDummies as $dum) {
        if (strpos($digitsOnly, $dum) !== false) {
            $isDummy = true;
            break;
        }
    }
    // Check repeated blocks like 112233444
    if (!$isDummy && strlen($digitsOnly) >= 6 && ($digitsOnly[0] === $digitsOnly[1] && $digitsOnly[2] === $digitsOnly[3] && $digitsOnly[4] === $digitsOnly[5])) {
        $isDummy = true;
    }
}

if ($isDummy) {
    http_response_code(200);
    echo json_encode([
        'success' => false,
        'error' => 'invalid_phone',
        'message' => 'Barah-e-karam apna durust official WhatsApp number country code (+966) ke sath darj karein. Dummy numbers qabil-e-qubool nahi hain.'
    ]);
    exit;
}

// Duplicate Phone Check across existing drivers
$last9 = substr($digitsOnly, -9);
if (strlen($last9) >= 9) {
    foreach ($db['drivers'] as $existingDriver) {
        $existingKey = strtoupper(trim($existingDriver['key'] ?? ''));
        if ($existingKey !== $cleanKey) {
            $exPhone = $existingDriver['whatsapp'] ?? $existingDriver['phone'] ?? '';
            $exDigits = preg_replace('/[^0-9]/', '', $exPhone);
            if (strlen($exDigits) >= 9 && substr($exDigits, -9) === $last9) {
                http_response_code(200);
                echo json_encode([
                    'success' => false,
                    'error' => 'duplicate_phone',
                    'message' => "Yeh WhatsApp number ($whatsapp) pehle se kisi doosri key ke sath registered hai. Barah-e-karam apna alag number darj karein."
                ]);
                exit;
            }
        }
    }
}


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
