<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Token, X-Admin-Password');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$db_file = __DIR__ . '/../driving_care_db.json';

function get_admin_credentials() {
    $configFile = __DIR__ . '/admin_config.php';
    if (file_exists($configFile)) {
        return require $configFile;
    }
    return [
        'username' => getenv('DC_ADMIN_USER') ?: 'admin',
        'password' => getenv('DC_ADMIN_PASS') ?: 'DrivingCare@2026#Admin',
        'allowed_users' => ['ikramadmin', 'ikram', 'bilal', 'admin'],
        'secret_salt' => 'dc_secure_salt_saudia_2026',
    ];
}

function get_db() {
    global $db_file;
    $creds = get_admin_credentials();
    if (!file_exists($db_file)) {
        $initial = [
            'admin' => [
                'username' => $creds['username'],
                'allowed_users' => $creds['allowed_users']
            ],
            'drivers' => [],
            'logs' => []
        ];
        file_put_contents($db_file, json_encode($initial, JSON_PRETTY_PRINT));
        return $initial;
    }
    $data = json_decode(file_get_contents($db_file), true);
    if (!is_array($data)) {
        $data = ['drivers' => [], 'logs' => []];
    }
    $data['admin'] = [
        'username' => $creds['username'],
        'allowed_users' => $creds['allowed_users']
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
    $creds = get_admin_credentials();
    $salt = $creds['secret_salt'] ?? 'dc_secure_salt_saudia_2026';
    $valid_token = hash('sha256', 'driving_care_master_' . $salt . '_' . date('Y-m-d'));

    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = '';
    if (preg_match('/Bearer\s+(\S+)/', $auth, $m)) {
        $token = $m[1];
    } elseif (!empty($_SERVER['HTTP_X_ADMIN_TOKEN'])) {
        $token = $_SERVER['HTTP_X_ADMIN_TOKEN'];
    }

    if ($token && $token === $valid_token) {
        return true;
    }

    // Check direct password header
    $pw_header = $_SERVER['HTTP_X_ADMIN_PASSWORD'] ?? '';
    if ($pw_header && ($pw_header === $creds['password'] || hash_equals($creds['password'], $pw_header))) {
        return true;
    }

    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Admin Authentication Required.']);
    exit;
}
