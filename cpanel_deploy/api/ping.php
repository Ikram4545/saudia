<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$rawKey = trim($data['key'] ?? '');
$cleanKey = strtoupper($rawKey);
$normalizedKey = preg_replace('/[^A-Z0-9]/', '', $cleanKey);
$device = $data['device'] ?? 'Android Mobile';
$driverName = $data['driverName'] ?? '';
$client_ip = get_client_ip();

$db = get_db();
$found = null;

if (!empty($cleanKey)) {
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
            $driver['online'] = true;
            $driver['lastPing'] = date('c');
            $driver['ip'] = $client_ip;
            $driver['device'] = $device;
            $found = $driver;
            break;
        }
    }
}

// Auto-register offline-activated drivers when they first report online
if (!$found && !empty($driverName) && !empty($cleanKey)) {
    $newRecord = [
        'key' => $cleanKey,
        'name' => $driverName,
        'phone' => $data['phone'] ?? '+966 Driver',
        'city' => 'Saudi Arabia',
        'status' => 'active',
        'daysLeft' => intval($data['daysLeft'] ?? 30),
        'activeUntil' => time() * 1000 + intval($data['daysLeft'] ?? 30) * 86400 * 1000,
        'online' => true,
        'lastPing' => date('c'),
        'ip' => $client_ip,
        'device' => $device
    ];
    $db['drivers'][] = $newRecord;
    array_unshift($db['logs'], [
        'event' => 'Offline Key Activated & Synced',
        'name' => $driverName,
        'key' => $cleanKey,
        'device' => $device,
        'ip' => $client_ip,
        'timestamp' => date('g:i:s A')
    ]);
    if (count($db['logs']) > 50) array_pop($db['logs']);
    $found = $newRecord;
}

if ($found) {
    save_db($db);
    echo json_encode([
        'success' => true,
        'status' => $found['status'],
        'daysLeft' => $found['daysLeft'],
        'driver' => [
            'name' => $found['name'],
            'key' => $found['key'],
            'status' => $found['status']
        ]
    ]);
} else {
    echo json_encode([
        'success' => false,
        'status' => 'unknown'
    ]);
}
