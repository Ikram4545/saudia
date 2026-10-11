<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$key = strtoupper(trim($data['key'] ?? ''));
$device = $data['device'] ?? 'Android Device';
$settings = $data['settings'] ?? [];
$client_ip = get_client_ip();

$db = get_db();
$driver_name = 'Driver';

foreach ($db['drivers'] as &$driver) {
    if (strtoupper($driver['key']) === $key) {
        $driver['settings'] = $settings;
        $driver['lastPing'] = date('c');
        $driver['ip'] = $client_ip;
        $driver_name = $driver['name'];
        break;
    }
}

array_unshift($db['logs'], [
    'event' => 'Settings Applied',
    'name' => $driver_name,
    'key' => $key ?: 'ACTIVE',
    'device' => $device,
    'ip' => $client_ip,
    'timestamp' => date('g:i:s A')
]);
if (count($db['logs']) > 50) array_pop($db['logs']);
save_db($db);

echo json_encode([
    'success' => true,
    'message' => 'Settings saved successfully'
]);
