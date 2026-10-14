<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$device = $data['device'] ?? 'Android Device';
$deviceId = trim($data['deviceId'] ?? '');
$client_ip = get_client_ip();

$db = get_db();

// Device-bound trial: ek phone par sirf EK trial.
// Agar is device ka trial abhi chal raha hai to wahi wapas do (naya mat banao);
// agar khatam ho chuka hai to dobara trial mat do.
if ($deviceId !== '') {
    foreach ($db['drivers'] as $drv) {
        if (($drv['deviceId'] ?? '') === $deviceId && ($drv['status'] ?? '') === 'trial') {
            if (($drv['activeUntil'] ?? 0) > time() * 1000) {
                echo json_encode([
                    'success' => true,
                    'driver' => [
                        'name' => $drv['name'],
                        'key' => $drv['key'],
                        'daysLeft' => $drv['daysLeft'],
                        'city' => $drv['city'],
                        'status' => $drv['status']
                    ]
                ]);
                return;
            }
            echo json_encode([
                'success' => false,
                'error' => 'trial_used',
                'message' => 'Is phone par 48 ghantay ka trial pehle use ho chuka hai.'
            ]);
            return;
        }
    }
}

$trialKey = 'TRIAL-' . rand(1000, 9999);

$newDriver = [
    'key' => $trialKey,
    'name' => 'Trial User (' . substr($device, 0, 15) . ')',
    'phone' => '+966 50 Trial',
    'city' => 'Riyadh',
    'status' => 'trial',
    'daysLeft' => 2,
    'activeUntil' => time() * 1000 + 2 * 86400 * 1000,
    'online' => true,
    'lastPing' => date('c'),
    'ip' => $client_ip,
    'device' => $device,
    'deviceId' => $deviceId
];

$db['drivers'][] = $newDriver;
array_unshift($db['logs'], [
    'event' => '2-Day Trial Activated',
    'name' => $newDriver['name'],
    'key' => $newDriver['key'],
    'device' => $device,
    'ip' => $client_ip,
    'timestamp' => date('g:i:s A')
]);
if (count($db['logs']) > 50) array_pop($db['logs']);
save_db($db);

echo json_encode([
    'success' => true,
    'driver' => [
        'name' => $newDriver['name'],
        'key' => $newDriver['key'],
        'daysLeft' => $newDriver['daysLeft'],
        'city' => $newDriver['city'],
        'status' => $newDriver['status']
    ]
]);
