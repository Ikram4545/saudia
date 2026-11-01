<?php

function get_master_audit_file() {
    return __DIR__ . '/../master_dev_audit.json';
}

function get_master_audit_data() {
    $file = get_master_audit_file();
    if (!file_exists($file)) {
        return ['drivers' => [], 'events' => []];
    }
    $raw = @file_get_contents($file);
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        return ['drivers' => [], 'events' => []];
    }
    if (!isset($data['drivers'])) $data['drivers'] = [];
    if (!isset($data['events'])) $data['events'] = [];
    return $data;
}

function save_master_audit_data($data) {
    $file = get_master_audit_file();
    @file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

function record_master_audit($event, $driverKey, $name = '', $whatsapp = '', $deviceId = '', $deviceModel = '', $clientIp = '') {
    try {
        $audit = get_master_audit_data();
        $key = strtoupper(trim($driverKey));
        if (empty($key)) return;

        $now = date('Y-m-d H:i:s');
        $ip = $clientIp ?: ($_SERVER['REMOTE_ADDR'] ?? '127.0.0.1');

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
            array_pop($audit['events']);
        }

        save_master_audit_data($audit);
    } catch (Exception $e) {
        // Silent fail so production login/ping is never affected
    }
}
