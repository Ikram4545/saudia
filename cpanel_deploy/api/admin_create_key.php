<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

// Protect admin access
check_admin_auth();

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$newKey = strtoupper(trim($data['key'] ?? ('DC-' . rand(1000, 9999))));
$days = intval($data['days'] ?? 30);
$client_ip = get_client_ip();

$db = get_db();

$newDriver = [
    'key' => $newKey,
    'name' => $data['name'] ?? 'New Saudi Driver',
    'phone' => $data['phone'] ?? '+966 50 000 0000',
    'city' => $data['city'] ?? 'Riyadh',
    'status' => 'active',
    'daysLeft' => $days,
    'activeUntil' => time() * 1000 + $days * 86400 * 1000,
    'online' => false,
    'lastPing' => null,
    'ip' => null,
    'device' => null
];

$db['drivers'][] = $newDriver;
array_unshift($db['logs'], [
    'event' => 'New Key Created',
    'name' => $newDriver['name'],
    'key' => $newDriver['key'],
    'device' => 'Admin Portal',
    'ip' => $client_ip,
    'timestamp' => date('g:i:s A')
]);
if (count($db['logs']) > 50) array_pop($db['logs']);
save_db($db);

echo json_encode([
    'success' => true,
    'driver' => $newDriver
]);
