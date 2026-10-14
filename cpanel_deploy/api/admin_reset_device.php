<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');
check_admin_auth();

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$key = strtoupper(trim($data['key'] ?? ''));

if (empty($key)) {
    echo json_encode(['success' => false, 'message' => 'Key parameter is required.']);
    exit;
}

$db = get_db();
$updated = false;

foreach ($db['drivers'] as &$driver) {
    if (strtoupper(trim($driver['key'] ?? '')) === $key) {
        $driver['boundDeviceId'] = null;
        $driver['device'] = 'Reset (Pending New Phone)';
        $updated = true;
        break;
    }
}

if ($updated) {
    array_unshift($db['logs'], [
        'event' => 'Device Binding Reset',
        'name' => $key,
        'key' => $key,
        'device' => 'Admin Action',
        'ip' => get_client_ip(),
        'timestamp' => date('g:i:s A')
    ]);
    if (count($db['logs']) > 50) array_pop($db['logs']);
    save_db($db);
    echo json_encode([
        'success' => true,
        'message' => "Key $key ki device binding reset ho chuki hai. Naya phone bind kiya ja sakta hai."
    ]);
} else {
    echo json_encode(['success' => false, 'message' => "Driver key $key nahi mili."]);
}
