<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Token, X-Admin-Password');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$db_file = __DIR__ . '/../driving_care_db.json';

function get_db() {
    global $db_file;
    if (!file_exists($db_file)) {
        $initial = [
            'admin' => [
                'username' => 'Ikram',
                'password' => 'Ikram445@@',
                'allowed_users' => ['ikram', 'bilal', 'admin']
            ],
            'drivers' => [
                [
                    'key' => 'DC-8921',
                    'name' => 'Tariq Al-Harbi',
                    'phone' => '+966 50 491 8821',
                    'city' => 'Riyadh',
                    'status' => 'active',
                    'daysLeft' => 30,
                    'activeUntil' => time() * 1000 + 30 * 86400 * 1000,
                    'online' => false,
                    'lastPing' => null,
                    'ip' => null,
                    'device' => null
                ],
                [
                    'key' => 'BILAL-VIP',
                    'name' => 'Bilal (Owner Admin)',
                    'phone' => '+966 53 419 9549',
                    'city' => 'Saudi Arabia',
                    'status' => 'active',
                    'daysLeft' => 365,
                    'activeUntil' => time() * 1000 + 365 * 86400 * 1000,
                    'online' => false,
                    'lastPing' => null,
                    'ip' => null,
                    'device' => null
                ],
                [
                    'key' => 'ADNAN-VIP',
                    'name' => 'Adnan (Driver)',
                    'phone' => '+966 50 123 4567',
                    'city' => 'Riyadh',
                    'status' => 'active',
                    'daysLeft' => 30,
                    'activeUntil' => time() * 1000 + 30 * 86400 * 1000,
                    'online' => false,
                    'lastPing' => null,
                    'ip' => null,
                    'device' => null
                ]
            ],
            'logs' => []
        ];
        file_put_contents($db_file, json_encode($initial, JSON_PRETTY_PRINT));
        return $initial;
    }
    $data = json_decode(file_get_contents($db_file), true);
    // Ensure strict master password
    $data['admin'] = [
        'username' => 'Ikram',
        'password' => 'Ikram445@@',
        'allowed_users' => ['ikram', 'bilal', 'admin']
    ];
    return $data;
}

function save_db($db) {
    global $db_file;
    file_put_contents($db_file, json_encode($db, JSON_PRETTY_PRINT));
}

function get_client_ip() {
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($ips[0]);
    }
    return $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}

function check_admin_auth() {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = '';
    if (preg_match('/Bearer\s+(\S+)/', $auth, $m)) {
        $token = $m[1];
    } elseif (!empty($_SERVER['HTTP_X_ADMIN_TOKEN'])) {
        $token = $_SERVER['HTTP_X_ADMIN_TOKEN'];
    }
    
    $valid_token = hash('sha256', 'driving_care_master_Ikram445@@_' . date('Y-m-d'));
    
    if ($token && $token === $valid_token) {
        return true;
    }
    
    // Check direct password header
    $pw_header = $_SERVER['HTTP_X_ADMIN_PASSWORD'] ?? '';
    if ($pw_header && ($pw_header === 'Ikram445@@' || $pw_header === 'ikram445@@')) {
        return true;
    }
    
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Admin Authentication Required. Please login with admin password.']);
    exit;
}
