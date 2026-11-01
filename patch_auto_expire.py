# 1. Update ping.php
ping_path = r"F:\download\Custom_Coding_and_Projects\saudia cleint\cpanel_deploy\api\ping.php"
with open(ping_path, "r", encoding="utf-8") as f:
    c = f.read()

target_ping = '// 3. If admin clicked "Reset Device", boundDeviceId is null -> INSTANT REMOTE KILL-SWITCH'
replacement_ping = """// 2b. Check 30-Day Automatic Calendar Expiration
$nowMs = time() * 1000;
$nowSec = time();
$isCalendarExpired = false;

if (!empty($found['activeUntil']) && is_numeric($found['activeUntil']) && $found['activeUntil'] > 0) {
    if ($nowMs > intval($found['activeUntil'])) {
        $isCalendarExpired = true;
    }
} elseif (!empty($found['activatedAt'])) {
    $actSec = strtotime($found['activatedAt']);
    if ($actSec && ($nowSec - $actSec) > (30 * 86400)) {
        $isCalendarExpired = true;
    }
}

if ($isCalendarExpired) {
    $found['status'] = 'expired';
    $found['daysLeft'] = 0;
    save_db($db);
    echo json_encode([
        'success' => false,
        'lock' => true,
        'error' => 'key_expired',
        'status' => 'expired',
        'message' => 'Aapka 30 din ka license expire ho chuka hai. Renewal ke liye admin se rabta karein.'
    ]);
    exit;
}

// 3. If admin clicked "Reset Device", boundDeviceId is null -> INSTANT REMOTE KILL-SWITCH"""

if "Check 30-Day Automatic Calendar Expiration" not in c:
    assert target_ping in c, "target_ping not found"
    c = c.replace(target_ping, replacement_ping, 1)
    with open(ping_path, "w", encoding="utf-8") as f:
        f.write(c)
    print("ping.php auto-expire check added")

# 2. Update login.php
login_path = r"F:\download\Custom_Coding_and_Projects\saudia cleint\cpanel_deploy\api\login.php"
with open(login_path, "r", encoding="utf-8") as f:
    c = f.read()

target_login = '        // Device Binding Check'
replacement_login = """        // Check 30-Day Automatic Calendar Expiration
        $nowMs = time() * 1000;
        $nowSec = time();
        $isCalendarExpired = false;

        if (!empty($driver['activeUntil']) && is_numeric($driver['activeUntil']) && $driver['activeUntil'] > 0) {
            if ($nowMs > intval($driver['activeUntil'])) {
                $isCalendarExpired = true;
            }
        } elseif (!empty($driver['activatedAt'])) {
            $actSec = strtotime($driver['activatedAt']);
            if ($actSec && ($nowSec - $actSec) > (30 * 86400)) {
                $isCalendarExpired = true;
            }
        }

        if ($isCalendarExpired) {
            $driver['status'] = 'expired';
            $driver['daysLeft'] = 0;
            save_db($db);
            http_response_code(200);
            echo json_encode([
                'success' => false,
                'error' => 'key_expired',
                'message' => 'Aapka 30 din ka license expire ho chuka hai. Renewal ke liye admin se rabta karein.'
            ]);
            exit;
        }

        // Device Binding Check"""

if "Check 30-Day Automatic Calendar Expiration" not in c:
    assert target_login in c, "target_login not found"
    c = c.replace(target_login, replacement_login, 1)
    with open(login_path, "w", encoding="utf-8") as f:
        f.write(c)
    print("login.php auto-expire check added")
