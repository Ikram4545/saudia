<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

// Protect admin access
check_admin_auth();

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$newKey = strtoupper(trim($data['key'] ?? ('DC-' . rand(1000, 9999))));
$days = intval($data['days'] ?? 30);
$name = trim($data['name'] ?? 'New Saudi Driver');
$client_ip = get_client_ip();

// Master Ed25519 Seed (Hex) for offline signature
$seedHex = '21f7e0b59e44c07d32b47b1aa0f0094e9ce664a45f169a7e8fb84b3eb7b34437';
$signedKey = null;

if (function_exists('sodium_crypto_sign_seed_keypair')) {
    try {
        $keypair = sodium_crypto_sign_seed_keypair(hex2bin($seedHex));
        $secretKey = sodium_crypto_sign_secretkey($keypair);
        $expMs = (time() + ($days * 86400)) * 1000;
        $payloadObj = [
            'key' => $newKey,
            'name' => $name,
            'days' => $days,
            'exp' => $expMs
        ];
        $payloadJson = json_encode($payloadObj, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        $payloadB64 = base64_encode($payloadJson);
        $sig = sodium_crypto_sign_detached($payloadB64, $secretKey);
        $sigB64 = base64_encode($sig);
        $signedKey = 'DCS-' . $payloadB64 . '.' . $sigB64;
    } catch (\Throwable $e) {}
}

$db = get_db();

$newDriver = [
    'key' => $newKey,
    'signedKey' => $signedKey,
    'name' => $name,
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
$db['logs'][] = [
    'event' => 'New Key Created',
    'name' => $newDriver['name'],
    'key' => $newDriver['key'],
    'device' => 'Admin Portal',
    'ip' => $client_ip,
    'timestamp' => date('g:i:s A')
];
if (count($db['logs']) > 50) array_shift($db['logs']);
save_db($db);

echo json_encode([
    'success' => true,
    'driver' => $newDriver,
    'signedKey' => $signedKey
]);
