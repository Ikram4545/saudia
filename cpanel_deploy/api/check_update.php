<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$configFile = __DIR__ . '/app_update_config.json';
$config = [];
if (file_exists($configFile)) {
    $config = json_decode(file_get_contents($configFile), true) ?? [];
}

$minCode = intval($config['min_version_code'] ?? 7);
$latestName = $config['latest_version_name'] ?? '2.6.0';
$releaseDate = $config['release_date'] ?? '2026-10-27';
$forceEnabled = !empty($config['force_update']);

// Read client version
$clientCode = intval($_GET['code'] ?? $_POST['version_code'] ?? 0);

$updateRequired = $forceEnabled && ($clientCode < $minCode);

echo json_encode([
    'success' => true,
    'update_required' => $updateRequired,
    'force_update' => $forceEnabled,
    'min_version_code' => $minCode,
    'latest_version_name' => $latestName,
    'release_date' => $releaseDate,
    'title' => $config['title'] ?? '⚠️ Zaroori Update Dastyab Hai',
    'message' => $config['message'] ?? 'Driving Care ka naya version aa chuka hai. Purana version band ho gaya hai. Jab aap update karenge tabhi yeh app chalegi.',
    'apk_url' => $config['apk_url'] ?? 'https://drivewithbilal.com/DrivingCare.apk',
    'download_page' => $config['download_page'] ?? 'https://drivewithbilal.com/download.php'
]);
