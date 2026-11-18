<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Token, X-Admin-Password');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$db_file = __DIR__ . '/../driving_care_db.json';
$sqlite_file = __DIR__ . '/../driving_care.sqlite';
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
 * Open ACID SQLite3 connection in WAL mode with 15s busy timeout.
 * Guarantees zero file corruption even under hundreds of concurrent requests.
 */
function get_dc_sqlite() {
    static $pdo = null;
    if ($pdo !== null) {
        return $pdo;
    }
    global $sqlite_file;
    if (!class_exists('PDO') || !in_array('sqlite', PDO::getAvailableDrivers())) {
        return null;
    }
    try {
        $pdo = new PDO('sqlite:' . $sqlite_file, null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_TIMEOUT => 15,
        ]);
        $pdo->exec('PRAGMA journal_mode = WAL;');
        $pdo->exec('PRAGMA synchronous = FULL;');
        $pdo->exec('PRAGMA busy_timeout = 15000;');
        $pdo->exec('
            CREATE TABLE IF NOT EXISTS kv_store (
                k TEXT PRIMARY KEY,
                v TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            );
        ');
        $pdo->exec('
            CREATE TABLE IF NOT EXISTS drivers_archive (
                license_key TEXT PRIMARY KEY,
                name TEXT,
                phone TEXT,
                driver_json TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            );
        ');
        return $pdo;
    } catch (Throwable $e) {
        error_log("DrivingCare SQLite init warning: " . $e->getMessage());
        $pdo = null;
        return null;
    }
}

function read_json_file_safely($filePath) {
    if (!file_exists($filePath)) return null;
    $content = false;
    for ($attempt = 0; $attempt < 6; $attempt++) {
        $fp = @fopen($filePath, 'rb');
        if ($fp) {
            if (flock($fp, LOCK_SH)) {
                $size = @filesize($filePath);
                $content = ($size > 0) ? fread($fp, $size) : '';
                flock($fp, LOCK_UN);
            }
            fclose($fp);
        }
        if ($content !== false && strlen($content) > 10) {
            break;
        }
        usleep(25000);
    }
    if ($content !== false && strlen($content) > 10) {
        $decoded = json_decode($content, true);
        if (is_array($decoded)) return $decoded;
    }
    return null;
}

function atomic_write_json_file($filePath, $jsonStr) {
    $dir = dirname($filePath);
    $tmp_file = @tempnam($dir, 'dctmp_');
    if ($tmp_file === false) {
        $tmp_file = $filePath . '.' . uniqid('tmp_', true);
    }
    $written = @file_put_contents($tmp_file, $jsonStr, LOCK_EX);
    if ($written !== false && $written > 0) {
        @chmod($tmp_file, 0644);
        if (@rename($tmp_file, $filePath)) {
            return true;
        }
    }
    @unlink($tmp_file);
    return @file_put_contents($filePath, $jsonStr, LOCK_EX) !== false;
}

/**
 * Primary DB Reader:
 * 1. Reads atomically from SQLite WAL database.
 * 2. Auto-migrates existing driving_care_db.json into SQLite on first run.
 * 3. Auto-recovers from .bak if ever needed.
 */
function get_db() {
    global $db_file;
    $creds = get_admin_credentials();
    $bak_file = $db_file . '.bak';
    $data = null;

    // 1. Try SQLite primary storage
    $pdo = get_dc_sqlite();
    if ($pdo) {
        try {
            $stmt = $pdo->prepare('SELECT v FROM kv_store WHERE k = :k LIMIT 1');
            $stmt->execute([':k' => 'db_state']);
            $row = $stmt->fetch();
            if ($row && !empty($row['v'])) {
                $decoded = json_decode($row['v'], true);
                if (is_array($decoded) && isset($decoded['drivers'])) {
                    $data = $decoded;
                }
            }
        } catch (Throwable $e) {
            error_log("DrivingCare SQLite read warning: " . $e->getMessage());
        }
    }

    // 2. First-boot migration or fallback from JSON / .bak
    if ($data === null) {
        $jsonData = read_json_file_safely($db_file);
        if (!is_array($jsonData) || !isset($jsonData['drivers']) || (empty($jsonData['drivers']) && file_exists($bak_file) && filesize($bak_file) > 100)) {
            $bakData = read_json_file_safely($bak_file);
            if (is_array($bakData) && !empty($bakData['drivers'])) {
                $jsonData = $bakData;
                error_log("DrivingCare: Auto-restored database from .bak file.");
            }
        }

        if (is_array($jsonData) && isset($jsonData['drivers'])) {
            $data = $jsonData;
            // Migrate seamlessly into SQLite immediately
            if ($pdo) {
                save_db($data);
            }
        } else {
            $data = [
                'drivers' => [],
                'logs' => []
            ];
            save_db($data, true);
        }
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
 * Primary DB Writer:
 * 1. Accidental empty-wipe protection (checks SQLite + JSON before allowing empty drivers).
 * 2. ACID SQLite WAL transaction + permanent drivers_archive upsert.
 * 3. Atomic JSON mirror + .bak + daily rolling backups (both JSON and SQLite).
 */
function save_db($db, $force_empty = false) {
    global $db_file, $sqlite_file, $backup_dir;
    if (!is_array($db)) return false;

    $incomingDrivers = (isset($db['drivers']) && is_array($db['drivers'])) ? $db['drivers'] : [];
    $pdo = get_dc_sqlite();

    // SAFEGUARD 1: Block accidental wiping of populated database
    if (!$force_empty && empty($incomingDrivers)) {
        if ($pdo) {
            try {
                $stmt = $pdo->prepare('SELECT v FROM kv_store WHERE k = :k LIMIT 1');
                $stmt->execute([':k' => 'db_state']);
                $row = $stmt->fetch();
                if ($row && !empty($row['v'])) {
                    $existing = json_decode($row['v'], true);
                    if (is_array($existing) && !empty($existing['drivers'])) {
                        error_log("DrivingCare Protection: Blocked attempted empty wipe of SQLite database.");
                        return false;
                    }
                }
            } catch (Throwable $e) {}
        }
        if (file_exists($db_file) && filesize($db_file) > 100) {
            $existing = read_json_file_safely($db_file);
            if (is_array($existing) && !empty($existing['drivers'])) {
                error_log("DrivingCare Protection: Blocked attempted empty wipe of JSON database.");
                return false;
            }
        }
    }

    $json = json_encode($db, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    if ($json === false || strlen($json) < 10) return false;

    $nowTs = time();
    $sqliteSaved = false;

    // SAFEGUARD 2: ACID SQLite WAL Transaction + Drivers Archive
    if ($pdo) {
        try {
            $pdo->beginTransaction();
            $stmt = $pdo->prepare('
                INSERT INTO kv_store (k, v, updated_at)
                VALUES (:k, :v, :t)
                ON CONFLICT(k) DO UPDATE SET v = excluded.v, updated_at = excluded.updated_at
            ');
            $stmt->execute([
                ':k' => 'db_state',
                ':v' => $json,
                ':t' => $nowTs
            ]);

            if (!empty($incomingDrivers)) {
                $archStmt = $pdo->prepare('
                    INSERT INTO drivers_archive (license_key, name, phone, driver_json, updated_at)
                    VALUES (:lk, :nm, :ph, :dj, :t)
                    ON CONFLICT(license_key) DO UPDATE SET
                        name = CASE WHEN excluded.name != "" AND excluded.name != "Driver" AND excluded.name != "Unassigned Driver (Batch)" THEN excluded.name ELSE drivers_archive.name END,
                        phone = CASE WHEN excluded.phone != "" THEN excluded.phone ELSE drivers_archive.phone END,
                        driver_json = excluded.driver_json,
                        updated_at = excluded.updated_at
                ');
                foreach ($incomingDrivers as $drv) {
                    $lk = strtoupper(trim($drv['key'] ?? ''));
                    if (empty($lk)) continue;
                    $archStmt->execute([
                        ':lk' => $lk,
                        ':nm' => trim($drv['name'] ?? ''),
                        ':ph' => trim($drv['whatsapp'] ?? ($drv['phone'] ?? '')),
                        ':dj' => json_encode($drv, JSON_UNESCAPED_UNICODE),
                        ':t' => $nowTs
                    ]);
                }
            }

            $pdo->commit();
            $sqliteSaved = true;
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            error_log("DrivingCare SQLite save warning: " . $e->getMessage());
        }
    }

    // SAFEGUARD 3: Keep .bak copy of previous valid JSON
    if (file_exists($db_file) && filesize($db_file) > 50) {
        @copy($db_file, $db_file . '.bak');
    }

    // SAFEGUARD 4: Atomic JSON mirror for backward compatibility
    $jsonSaved = atomic_write_json_file($db_file, $json);

    // SAFEGUARD 5: Daily rolling backups (JSON + SQLite)
    if (!empty($incomingDrivers)) {
        if (!is_dir($backup_dir)) {
            @mkdir($backup_dir, 0755, true);
        }
        $today = date('Y-m-d');
        $daily_json = $backup_dir . '/driving_care_db_' . $today . '.json';
        if (!file_exists($daily_json) || (time() - filemtime($daily_json)) > 3600) {
            atomic_write_json_file($daily_json, $json);
        }
        if (file_exists($sqlite_file)) {
            $daily_sqlite = $backup_dir . '/driving_care_' . $today . '.sqlite';
            if (!file_exists($daily_sqlite)) {
                @copy($sqlite_file, $daily_sqlite);
            }
        }
    }

    return $sqliteSaved || $jsonSaved;
}

function get_client_ip() {
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($ips[0]);
    }
    return $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}

/**
 * Generate a persistent high-entropy token for admin session
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

    // 1. Persistent token
    $persistent_token = get_persistent_admin_token($creds);
    if ($token && ($token === $persistent_token || hash_equals($persistent_token, $token))) {
        return true;
    }

    // 2. Rolling 30-day window tokens for backward compatibility
    if ($token) {
        for ($i = 0; $i <= 30; $i++) {
            $past_token = hash('sha256', 'driving_care_master_' . $salt . '_' . date('Y-m-d', strtotime("-$i days")));
            if ($token === $past_token || hash_equals($past_token, $token)) {
                return true;
            }
        }
    }

    // 3. Direct password header
    $pw_header = $_SERVER['HTTP_X_ADMIN_PASSWORD'] ?? '';
    if ($pw_header && ($pw_header === $creds['password'] || hash_equals($creds['password'], $pw_header))) {
        return true;
    }

    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Admin Authentication Required.']);
    exit;
}
