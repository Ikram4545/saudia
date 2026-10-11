<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$key = strtoupper(trim($data['key'] ?? ''));
$client_ip = get_client_ip();

$db = get_db();
$found = null;

foreach ($db['drivers'] as &$driver) {
    if (strtoupper($driver['key']) === $key) {
        $driver['online'] = true;
        $driver['lastPing'] = date('c');
        $driver['ip'] = $client_ip;
        $found = $driver;
        break;
    }
}

if ($found) {
    save_db($db);
    echo json_encode([
        'success' => true,
        'status' => $found['status'],
        'daysLeft' => $found['daysLeft']
    ]);
} else {
    echo json_encode([
        'success' => false,
        'status' => 'unknown'
    ]);
}
