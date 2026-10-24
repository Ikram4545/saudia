<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

check_admin_auth();

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$count = max(1, min(100, intval($data['count'] ?? 10)));
$sellerName = trim($data['sellerName'] ?? 'Client KSA');
$salePrice = floatval($data['salePrice'] ?? 40.0);
$commissionPercent = floatval($data['commissionPercent'] ?? 30.0);
$myShare = round($salePrice * ($commissionPercent / 100.0), 2);
$clientShare = round($salePrice - $myShare, 2);
$status = trim($data['status'] ?? 'pending');
$client_ip = get_client_ip();

$chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
$charsLen = strlen($chars);

$db = get_db();
$existingKeys = [];
foreach ($db['drivers'] as $d) {
    if (!empty($d['key'])) {
        $existingKeys[strtoupper(trim($d['key']))] = true;
    }
}

function generate_secure_key(&$existingKeys, $chars, $charsLen) {
    for ($attempt = 0; $attempt < 1000; $attempt++) {
        $p1 = '';
        $p2 = '';
        for ($i = 0; $i < 4; $i++) {
            $p1 .= $chars[random_int(0, $charsLen - 1)];
            $p2 .= $chars[random_int(0, $charsLen - 1)];
        }
        $candidate = "DC-{$p1}-{$p2}";
        if (!isset($existingKeys[$candidate])) {
            $existingKeys[$candidate] = true;
            return $candidate;
        }
    }
    return "DC-" . strtoupper(bin2hex(random_bytes(4)));
}

$createdDrivers = [];
$nowStr = date('Y-m-d H:i:s');

for ($i = 0; $i < $count; $i++) {
    $newKey = generate_secure_key($existingKeys, $chars, $charsLen);
    $driverRecord = [
        'key' => $newKey,
        'signedKey' => null,
        'sellerName' => $sellerName,
        'name' => "Unassigned Driver (Batch)",
        'phone' => '',
        'city' => 'Saudi Arabia',
        'salePrice' => $salePrice,
        'feeSAR' => $salePrice,
        'commissionPercent' => $commissionPercent,
        'myShare' => $myShare,
        'clientShare' => $clientShare,
        'soldAt' => $nowStr,
        'status' => $status,
        'daysLeft' => 30,
        'activeUntil' => null,
        'online' => false,
        'lastPing' => null,
        'ip' => null,
        'device' => null,
        'boundDeviceId' => null,
        'requestedDeviceId' => null,
        'requestedDevice' => null,
        'requestedAt' => null
    ];
    $db['drivers'][] = $driverRecord;
    $createdDrivers[] = $driverRecord;
}

$db['logs'][] = [
    'event' => "Batch Generated: {$count} Unique Keys Created (Seller: {$sellerName})",
    'name' => 'System Admin',
    'key' => "BATCH-{$count}",
    'device' => 'Admin Portal',
    'ip' => $client_ip,
    'timestamp' => date('g:i:s A')
];

if (count($db['logs']) > 50) {
    $db['logs'] = array_slice($db['logs'], -50);
}

save_db($db);

echo json_encode([
    'success' => true,
    'count' => count($createdDrivers),
    'drivers' => $createdDrivers,
    'message' => "Successfully created {$count} cryptographically unique keys!"
]);
