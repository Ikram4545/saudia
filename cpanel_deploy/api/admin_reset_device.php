<?php
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/master_audit_helper.php';

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
        $driver['requestedDeviceId'] = null;
        $driver['device'] = 'Reset (Pending Approval)';
        $driver['status'] = 'pending'; // Requires Admin to explicitly Approve before re-login
        $driver['isReset'] = true;
        $driver['resetAt'] = date('Y-m-d H:i:s');
        $updated = true;
        break;
    }
}

if ($updated) {
    array_unshift($db['logs'], [
        'event' => 'Device Binding Reset (Pending Approval)',
        'name' => $key,
        'key' => $key,
        'device' => 'Admin Action',
        'ip' => get_client_ip(),
        'timestamp' => date('g:i:s A')
    ]);
    if (count($db['logs']) > 50) array_pop($db['logs']);
    save_db($db);
    record_master_audit('Device Reset by Bilal (Admin Portal)', $key, '', '', '', '', get_client_ip());
    $audit = get_master_audit_data();
    if (isset($audit['drivers'][$key])) {
        $audit['drivers'][$key]['bilalStatus'] = 'device_reset';
        $audit['drivers'][$key]['status'] = 'pending';
        save_master_audit_data($audit);
    }
    echo json_encode([
        'success' => true,
        'message' => "Key $key ki device binding reset ho chuki hai aur status Pending kar diya gaya hai. Driver ab aapki dobara approval ke baghair login nahi kar sakega."
    ]);
} else {
    echo json_encode(['success' => false, 'message' => "Driver key $key nahi mili."]);
}
