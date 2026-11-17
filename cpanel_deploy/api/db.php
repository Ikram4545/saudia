<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Token, X-Admin-Password');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$db_file = __DIR__ . '/../driving_care_db.json';
$backup_dir = __DIR__ . '/../backups';

function get_admin_credentials() {
    $configFile = __DIR__ . '/admin_config.php';
    if (file_exists($configFile)) {
        return require $configFile;
    }
    $u = getenv('DC_ADMIN_USER') ?: 'IkramAdmin';
    $p = getenv('DC_ADMIN_PASS') ?: 'DC#Saudi2026@SecureAdmin';
    $s = getenv('DC_ADMIN_SALT') ?: 'dc_salt_9a8b7c6d5e4f3a2b1c';
    return [
        'username' => $u,
        'password' => $p,
        'allowed_users' => ['ikramadmin', 'ikram', 'bilal', 'admin'],
        'secret_salt' => $s,
    ];
}

/**
 * Robust JSON database read with shared lock (LOCK_SH) and fallback to .bak / daily backup
 */
function get_db() {
    global $db_file, $backup_dir;
    $creds = get_admin_credentials();

    $bak_file = $db_file . '.bak';

    if (!file_exists($db_file)) {
        if (file_exists($bak_file) && filesize($bak_file) > 50) {
            @copy($bak_file, $db_file);
        } else {
            $initial = [
                'admin' => [
                    'username' => $creds['username'],
                    'allowed_users' => $creds['allowed_users']
                ],
                'drivers' => [],
                'logs' => []
            ];
            save_db($initial);
            return $initial;
        }
    }

    // Read with flock LOCK_SH and retry
    $content = false;
    for ($attempt = 0; $attempt < 6; $attempt++) {
        $fp = @fopen($db_file, 'rb');
        if ($fp) {
            if (flock($fp, LOCK_SH)) {
                $size = @filesize($db_file);
                $content = ($size > 0) ? fread($fp, $size) : '';
                flock($fp, LOCK_UN);
            }
            fclose($fp);
        }
        if ($content !== false && strlen($content) > 10) {
            break;
        }
        usleep(25000); // 25ms
    }

    $data = null;
    if ($content !== false && strlen($content) > 10) {
        $data = json_decode($content, true);
    }

    // CRITICAL RECOVERY: If main file is empty/corrupt or missing drivers, recover from backup!
    if (!is_array($data) || !isset($data['drivers']) || (empty($data['drivers']) && file_exists($bak_file) && filesize($bak_file) > 100)) {
        if (file_exists($bak_file) && filesize($bak_file) > 100) {
            $bak_raw = @file_get_contents($bak_file);
            $bak_data = json_decode($bak_raw, true);
            if (is_array($bak_data) && !empty($bak_data['drivers'])) {
                @copy($bak_file, $db_file);
                $data = $bak_data;
                error_log("DrivingCare: Auto-restored database from .bak file successfully.");
            }
        }
    }

    if (!is_array($data)) {
        $data = ['drivers' => [], 'logs' => []];
    }
    if (!isset($data['drivers']) || !is_array($data['drivers'])) {
        $data['drivers'] = [];
    }
    if (!isset($data['logs']) || !is_array($data['logs'])) {
        $data['logs'] = [];
    }

    $data['admin'] = [
        'username' => $creds['username'],
        'allowed_users' => $creds['allowed_users']
    ];
    return $data;
}

/**
 * Bulletproof atomic JSON database write with:
 * 1. Accidental empty overwrite protection
 * 2. Automated .bak copy
 * 3. Daily rolling backups
 * 4. Atomic temporary file swap via POSIX rename()
 */
function save_db($db, $force_empty = false) {
    global $db_file, $backup_dir;
    if (!is_array($db)) return false;

    // SAFEGUARD 1: Never allow accidental wiping of drivers
    if (!$force_empty && empty($db['drivers']) && file_exists($db_file) && filesize($db_file) > 100) {
        $existing_content = @file_get_contents($db_file);
        $existing_data = json_decode($existing_content, true);
        if (is_array($existing_data) && !empty($existing_data['drivers'])) {
            error_log("DrivingCare Protection: Refused to overwrite populated database with empty drivers array.");
            return false;
        }
    }

    $json = json_encode($db, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    if ($json === false || strlen($json) < 10) return false;

    // SAFEGUARD 2: Preserve existing working file as .bak
    if (file_exists($db_file) && filesize($db_file) > 50) {
        @copy($db_file, $db_file . '.bak');
    }

    // SAFEGUARD 3: Daily rolling backup
    if (!empty($db['drivers'])) {
        if (!is_dir($backup_dir)) {
            @mkdir($backup_dir, 0755, true);
        }
        $daily_backup = $backup_dir . '/driving_care_db_' . date('Y-m-d') . '.json';
        if (!file_exists($daily_backup)) {
            @file_put_contents($daily_backup, $json, LOCK_EX);
        }
    }

    // SAFEGUARD 4: Atomic file replacement (never truncates the target file directly)
    $dir = dirname($db_file);
    $tmp_file = tempnam($dir, 'dcdb_');
    if ($tmp_file === false) {
        $tmp_file = $db_file . '.' . uniqid('tmp_', true);
    }

    $written = @file_put_contents($tmp_file, $json, LOCK_EX);
    if ($written !== false && $written > 0) {
        @chmod($tmp_file, 0644);
        if (@rename($tmp_file, $db_file)) {
            return true;
        }
    }
    @unlink($tmp_file);

    // Fallback direct locked write
    return @file_put_contents($db_file, $json, LOCK_EX) !== false;
}

function get_client_ip() {
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($ips[0]);
    }
    return $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}

/**
 * Generate a persistent 60-day token for admin session
 */
function get_persistent_admin_token($creds) {
    $salt = $creds['secret_salt'] ?? 'dc_secure_salt_saudia_2026';
    return hash('sha256', 'driving_care_persistent_' . $salt . '_' . $creds['password']);
}

function check_admin_auth() {
    $creds = get_admin_credentials();
    $salt = $creds['secret_salt'] ?? 'dc_secure_salt_saudia_2026';
    
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = '';
    if (preg_match('/Bearer\s+(\S+)/', $auth, $m)) {
        $token = $m[1];
    } elseif (!empty($_SERVER['HTTP_X_ADMIN_TOKEN'])) {
        $token = $_SERVER['HTTP_X_ADMIN_TOKEN'];
    }

    // 1. Check persistent high-entropy token
    $persistent_token = get_persistent_admin_token($creds);
    if ($token && ($token === $persistent_token || hash_equals($persistent_token, $token))) {
        return true;
    }

    // 2. Check rolling window tokens (last 30 days) for backward compatibility
    if ($token) {
        for ($i = 0; $i <= 30; $i++) {
            $past_token = hash('sha256', 'driving_care_master_' . $salt . '_' . date('Y-m-d', strtotime("-$i days")));
            if ($token === $past_token || hash_equals($past_token, $token)) {
                return true;
            }
        }
    }

    // 3. Check direct password header
    $pw_header = $_SERVER['HTTP_X_ADMIN_PASSWORD'] ?? '';
    if ($pw_header && ($pw_header === $creds['password'] || hash_equals($creds['password'], $pw_header))) {
        return true;
    }

    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Admin Authentication Required.']);
    exit;
}
