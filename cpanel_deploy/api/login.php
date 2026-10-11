<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$rawKey = trim($data['key'] ?? '');
$cleanKey = strtoupper($rawKey);
$normalizedKey = preg_replace('/[^A-Z0-9]/', '', $cleanKey);
$device = $data['device'] ?? 'Android Device';
$client_ip = get_client_ip();

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
        $driver['online'] = true;
        $driver['lastPing'] = date('c');
        $driver['ip'] = $client_ip;
        $driver['device'] = $device;
        $found = $driver;
        break;
    }
}

if ($found) {
    array_unshift($db['logs'], [
        'event' => 'Driver Logged In',
        'name' => $found['name'],
        'key' => $found['key'],
        'device' => $device,
        'ip' => $client_ip,
        'timestamp' => date('g:i:s A')
    ]);
    if (count($db['logs']) > 50) array_pop($db['logs']);
    save_db($db);

    echo json_encode([
        'success' => true,
        'driver' => [
            'name' => $found['name'],
            'key' => $found['key'],
            'daysLeft' => $found['daysLeft'],
            'city' => $found['city'],
            'status' => $found['status']
        ]
    ]);
} else {
    array_unshift($db['logs'], [
        'event' => 'Failed Login Attempt',
        'name' => 'Unknown',
        'key' => $cleanKey,
        'device' => $device,
        'ip' => $client_ip,
        'timestamp' => date('g:i:s A')
    ]);
    if (count($db['logs']) > 50) array_pop($db['logs']);
    save_db($db);

    http_response_code(403);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid or Expired License Key'
    ]);
}
