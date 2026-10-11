<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

check_admin_auth();

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$key = trim($data['key'] ?? '');
$newStatus = trim($data['status'] ?? ''); // 'active' or 'locked' or 'expired'

if (!$key || !$newStatus) {
    http_response_code(400);
    die(json_encode(['success' => false, 'error' => 'Key and status are required']));
}

$db = get_db();
$found = false;

foreach ($db['drivers'] as &$driver) {
    if (strcasecmp($driver['key'], $key) === 0) {
        $found = true;
        $driver['status'] = $newStatus;
        array_unshift($db['logs'], [
            'event' => 'Driver Status Changed to ' . ucfirst($newStatus),
            'name' => $driver['name'],
            'key' => $driver['key'],
            'device' => 'Admin Portal',
            'ip' => get_client_ip(),
            'timestamp' => date('g:i:s A')
        ]);
        break;
    }
}

if ($found) {
    if (count($db['logs']) > 50) array_pop($db['logs']);
    save_db($db);
    echo json_encode(['success' => true, 'message' => 'Driver status updated successfully']);
} else {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Driver key not found']);
}
