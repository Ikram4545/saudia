<?php

function get_master_audit_file() {
    return __DIR__ . '/../master_dev_audit.json';
}

function get_master_audit_sqlite() {
    if (function_exists('get_dc_sqlite')) {
        return get_dc_sqlite();
    }
    static $pdo = null;
    if ($pdo !== null) return $pdo;
    if (!class_exists('PDO') || !in_array('sqlite', PDO::getAvailableDrivers())) {
        return null;
    }
    $sqlite_file = __DIR__ . '/../driving_care.sqlite';
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
        return $pdo;
    } catch (Throwable $e) {
        return null;
    }
}

function read_audit_json_locked($filePath) {
    if (!file_exists($filePath)) return null;
    $content = false;
    for ($attempt = 0; $attempt < 5; $attempt++) {
        $fp = @fopen($filePath, 'rb');
        if ($fp) {
            if (flock($fp, LOCK_SH)) {
                $size = @filesize($filePath);
                $content = ($size > 0) ? fread($fp, $size) : '';
                flock($fp, LOCK_UN);
            }
            fclose($fp);
        }
        if ($content !== false && strlen($content) > 10) break;
        usleep(20000);
    }
    if ($content !== false && strlen($content) > 10) {
        $decoded = json_decode($content, true);
        if (is_array($decoded)) return $decoded;
    }
    return null;
}

function write_audit_json_atomic($filePath, $jsonStr) {
    $dir = dirname($filePath);
    $tmp = @tempnam($dir, 'dcaud_');
    if ($tmp === false) {
        $tmp = $filePath . '.' . uniqid('tmp_', true);
    }
    $written = @file_put_contents($tmp, $jsonStr, LOCK_EX);
    if ($written !== false && $written > 0) {
        @chmod($tmp, 0644);
        if (@rename($tmp, $filePath)) {
            return true;
        }
    }
    @unlink($tmp);
    return @file_put_contents($filePath, $jsonStr, LOCK_EX) !== false;
}

function get_master_audit_data() {
    $file = get_master_audit_file();
    $bak_file = $file . '.bak';
    $data = null;

    // 1. Primary read from SQLite WAL store
    $pdo = get_master_audit_sqlite();
    if ($pdo) {
        try {
            $stmt = $pdo->prepare('SELECT v FROM kv_store WHERE k = :k LIMIT 1');
            $stmt->execute([':k' => 'master_audit_state']);
            $row = $stmt->fetch();
            if ($row && !empty($row['v'])) {
                $decoded = json_decode($row['v'], true);
                if (is_array($decoded) && isset($decoded['drivers'])) {
                    $data = $decoded;
                }
            }
        } catch (Throwable $e) {
            error_log("DrivingCare Audit SQLite read warning: " . $e->getMessage());
        }
    }

    // 2. First-boot migration or fallback from JSON / .bak
    if ($data === null) {
        $jsonData = read_audit_json_locked($file);
        if (!is_array($jsonData) || empty($jsonData['drivers'])) {
            $bakData = read_audit_json_locked($bak_file);
            if (is_array($bakData) && !empty($bakData['drivers'])) {
                $jsonData = $bakData;
            }
        }
        if (is_array($jsonData)) {
            $data = $jsonData;
            if (!isset($data['drivers']) || !is_array($data['drivers'])) $data['drivers'] = [];
            if (!isset($data['events']) || !is_array($data['events'])) $data['events'] = [];
            if ($pdo && !empty($data['drivers'])) {
                save_master_audit_data($data);
            }
        } else {
            $data = ['drivers' => [], 'events' => []];
        }
    }

    if (!isset($data['drivers']) || !is_array($data['drivers'])) $data['drivers'] = [];
    if (!isset($data['events']) || !is_array($data['events'])) $data['events'] = [];
    return $data;
}

function save_master_audit_data($data) {
    if (!is_array($data)) return false;
    $file = get_master_audit_file();
    $bak_file = $file . '.bak';
    $backup_dir = __DIR__ . '/../backups';

    $incomingDrivers = (isset($data['drivers']) && is_array($data['drivers'])) ? $data['drivers'] : [];
    $pdo = get_master_audit_sqlite();

    // SAFEGUARD: Never wipe existing audit contacts with an empty list
    if (empty($incomingDrivers)) {
        if ($pdo) {
            try {
                $stmt = $pdo->prepare('SELECT v FROM kv_store WHERE k = :k LIMIT 1');
                $stmt->execute([':k' => 'master_audit_state']);
                $row = $stmt->fetch();
                if ($row && !empty($row['v'])) {
                    $existing = json_decode($row['v'], true);
                    if (is_array($existing) && !empty($existing['drivers'])) {
                        error_log("DrivingCare Audit Protection: Blocked attempted empty wipe of audit records.");
                        return false;
                    }
                }
            } catch (Throwable $e) {}
        }
        if (file_exists($file) && filesize($file) > 100) {
            $existing = read_audit_json_locked($file);
            if (is_array($existing) && !empty($existing['drivers'])) {
                error_log("DrivingCare Audit Protection: Blocked attempted empty wipe of JSON audit.");
                return false;
            }
        }
    }

    $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    if ($json === false || strlen($json) < 10) return false;

    // 1. ACID SQLite save
    if ($pdo) {
        try {
            $pdo->beginTransaction();
            $stmt = $pdo->prepare('
                INSERT INTO kv_store (k, v, updated_at)
                VALUES (:k, :v, :t)
                ON CONFLICT(k) DO UPDATE SET v = excluded.v, updated_at = excluded.updated_at
            ');
            $stmt->execute([
                ':k' => 'master_audit_state',
                ':v' => $json,
                ':t' => time()
            ]);
            $pdo->commit();
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            error_log("DrivingCare Audit SQLite save warning: " . $e->getMessage());
        }
    }

    // 2. Preserve .bak copy + atomic JSON mirror + daily audit backup
    if (file_exists($file) && filesize($file) > 50) {
        @copy($file, $bak_file);
    }
    write_audit_json_atomic($file, $json);

    if (!empty($incomingDrivers)) {
        if (!is_dir($backup_dir)) {
            @mkdir($backup_dir, 0755, true);
        }
        $daily_audit = $backup_dir . '/master_dev_audit_' . date('Y-m-d') . '.json';
        if (!file_exists($daily_audit) || (time() - filemtime($daily_audit)) > 3600) {
            write_audit_json_atomic($daily_audit, $json);
        }
    }
    return true;
}

function record_master_audit($event, $driverKey, $name = '', $whatsapp = '', $deviceId = '', $deviceModel = '', $clientIp = '') {
    try {
        $key = strtoupper(trim($driverKey));
        if (empty($key)) return;

        $audit = get_master_audit_data();
        $now = date('Y-m-d H:i:s');
        $nowTs = time();
        $ip = $clientIp ?: ($_SERVER['REMOTE_ADDR'] ?? '127.0.0.1');

        // Throttle high-frequency Heartbeat Pings to once per 45 seconds per driver
        if ($event === 'Heartbeat Ping' && isset($audit['drivers'][$key])) {
            $lastSeenStr = $audit['drivers'][$key]['lastSeen'] ?? '';
            $lastSeenTs = $lastSeenStr ? strtotime($lastSeenStr) : 0;
            $hasNewContact = (!empty($whatsapp) && empty($audit['drivers'][$key]['whatsapp']))
                || (!empty($name) && $name !== 'Authorized Driver' && $name !== 'Driver' && ($audit['drivers'][$key]['name'] ?? '') !== $name);
            if (!$hasNewContact && ($nowTs - $lastSeenTs) < 45) {
                return;
            }
        }

        if (!isset($audit['drivers'][$key])) {
            $audit['drivers'][$key] = [
                'key' => $key,
                'name' => $name ?: 'Authorized Driver',
                'whatsapp' => $whatsapp ?: '',
                'deviceId' => $deviceId ?: '',
                'deviceModel' => $deviceModel ?: 'Android Mobile',
                'ip' => $ip,
                'firstSeen' => $now,
                'lastSeen' => $now,
                'pingCount' => 1,
                'status' => 'active',
                'bilalStatus' => 'active'
            ];
        } else {
            $d = &$audit['drivers'][$key];
            if (!empty($name) && $name !== 'Authorized Driver') $d['name'] = $name;
            if (!empty($whatsapp)) $d['whatsapp'] = $whatsapp;
            if (!empty($deviceId)) $d['deviceId'] = $deviceId;
            if (!empty($deviceModel)) $d['deviceModel'] = $deviceModel;
            $d['ip'] = $ip;
            $d['lastSeen'] = $now;
            $d['pingCount'] = ($d['pingCount'] ?? 0) + 1;
            $d['status'] = 'active';
        }

        // Add event
        array_unshift($audit['events'], [
            'timestamp' => $now,
            'event' => $event,
            'key' => $key,
            'name' => $audit['drivers'][$key]['name'] ?? $name,
            'whatsapp' => $audit['drivers'][$key]['whatsapp'] ?? $whatsapp,
            'deviceId' => $deviceId,
            'ip' => $ip,
            'device' => $deviceModel
        ]);

        if (count($audit['events']) > 300) {
            $audit['events'] = array_slice($audit['events'], 0, 300);
        }

        save_master_audit_data($audit);
    } catch (Throwable $e) {
        // Silent fail so production login/ping is never affected
    }
}
