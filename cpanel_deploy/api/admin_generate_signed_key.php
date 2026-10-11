<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');
check_admin_auth();

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$name = trim($data['name'] ?? 'Authorized Driver');
$days = intval($data['days'] ?? 30);
if ($days <= 0) $days = 30;
$key = strtoupper(trim($data['key'] ?? ('DC-' . rand(1000, 9999))));

// Master Ed25519 Private Key Seed
$seedHex = '21f7e0b59e44c07d32b47b1aa0f0094e9ce664a45f169a7e8fb84b3eb7b34437';
$signedKey = '';

try {
    if (function_exists('sodium_crypto_sign_seed_keypair')) {
        $keypair = sodium_crypto_sign_seed_keypair(hex2bin($seedHex));
        $secretKey = sodium_crypto_sign_secretkey($keypair);
        $expMs = (time() + ($days * 86400)) * 1000;
        
        $payload = [
            'key' => $key,
            'name' => $name,
            'days' => $days,
            'exp' => $expMs
        ];
        $payloadB64 = base64_encode(json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
        $sig = sodium_crypto_sign_detached($payloadB64, $secretKey);
        $sigB64 = base64_encode($sig);
        $signedKey = 'DCS-' . $payloadB64 . '.' . $sigB64;
    }
} catch (\Throwable $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error generating signature: ' . $e->getMessage()
    ]);
    exit;
}

echo json_encode([
    'success' => true,
    'key' => $key,
    'name' => $name,
    'days' => $days,
    'signedKey' => $signedKey
]);
