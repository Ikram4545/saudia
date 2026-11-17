<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true) ?? [];

$username = strtolower(trim($data['username'] ?? ''));
$password = trim($data['password'] ?? '');

$creds = get_admin_credentials();
$valid_users = $creds['allowed_users'] ?? ['ikramadmin', 'ikram', 'bilal', 'admin'];

if (in_array($username, $valid_users) && (hash_equals($creds['password'], $password) || $password === $creds['password'])) {
    // Generate persistent secure token (does not expire every 24 hours)
    $token = get_persistent_admin_token($creds);
    
    $db = get_db();
    $client_ip = get_client_ip();
    array_unshift($db['logs'], [
        'event' => 'Master Admin Logged In',
        'name' => ucfirst($username),
        'key' => 'ADMIN-AUTH',
        'device' => 'Web Browser',
        'ip' => $client_ip,
        'timestamp' => date('g:i:s A')
    ]);
    if (count($db['logs']) > 50) array_pop($db['logs']);
    save_db($db);
    
    echo json_encode([
        'success' => true,
        'token' => $token,
        'username' => ucfirst($username),
        'message' => 'Login kamyab! Khush amdeed.'
    ]);
} else {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Ghalat Username ya Password! Baraye meherbani sahi password darj karein.'
    ]);
}
