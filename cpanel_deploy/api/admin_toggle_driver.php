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
        $prevStatus = $driver['status'] ?? 'pending';
        $driver['status'] = $newStatus;
        
        if ($newStatus === 'active') {
            // If activating from pending or expiring, set 30 days
            $driver['daysLeft'] = 30;
            $driver['activeUntil'] = (time() + 30 * 86400) * 1000;
            $driver['activatedAt'] = date('Y-m-d H:i:s');
            
            // Bind device if requested from phone
            if (empty($driver['boundDeviceId']) && !empty($driver['requestedDeviceId'])) {
                $driver['boundDeviceId'] = $driver['requestedDeviceId'];
            }
            if (!empty($data['name']) && ($driver['name'] === 'Unassigned Driver' || strpos($driver['name'], 'Unassigned Driver') === 0)) {
                $driver['name'] = trim($data['name']);
            }
            if (!empty($data['phone'])) {
                $driver['phone'] = trim($data['phone']);
            }
            if (!empty($data['city'])) {
                $driver['city'] = trim($data['city']);
            }
        }
        
        array_unshift($db['logs'], [
            'event' => ($newStatus === 'active' && $prevStatus === 'pending') 
                ? "Driver Key {$driver['key']} Approved & Activated (30 Days)" 
                : ('Driver Status Changed to ' . ucfirst($newStatus)),
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
