<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

// Protect admin access
check_admin_auth();

$db = get_db();
$now = time() * 1000;

foreach ($db['drivers'] as &$driver) {
    if (!empty($driver['lastPing'])) {
        $last = strtotime($driver['lastPing']) * 1000;
        if ($now - $last > 60000) {
            $driver['online'] = false;
        }
    } else {
        $driver['online'] = false;
    }
}

echo json_encode([
    'drivers' => $db['drivers'],
    'logs' => $db['logs'],
    'serverTime' => date('c')
]);
