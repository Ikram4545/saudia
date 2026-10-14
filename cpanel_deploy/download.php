<?php
// Robust chunked APK downloader for Driving Care
$candidates = [
    __DIR__ . '/DrivingCare.apk',
    __DIR__ . '/Driving_Care_v2.4_Production.apk',
    __DIR__ . '/Driving_Care_Official_v2.0.apk',
];

$file = null;
foreach ($candidates as $c) {
    if (file_exists($c) && filesize($c) > 1000000) {
        $file = $c;
        break;
    }
}

if ($file) {
    $filename = "Driving_Care_v2.4.0.apk";
    $filesize = filesize($file);

    // Disable execution time limit for slow mobile connections
    @set_time_limit(0);

    // Clear any existing output buffers cleanly
    while (ob_get_level() > 0) {
        ob_end_clean();
    }

    header('Content-Description: File Transfer');
    header('Content-Type: application/vnd.android.package-archive');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Content-Transfer-Encoding: binary');
    header('Expires: 0');
    header('Cache-Control: public, must-revalidate, max-age=0');
    header('Pragma: public');
    header('Content-Length: ' . $filesize);
    header('Accept-Ranges: bytes');

    $handle = fopen($file, 'rb');
    if ($handle) {
        while (!feof($handle) && !connection_aborted()) {
            echo fread($handle, 65536);
            flush();
        }
        fclose($handle);
    }
    exit;
} else {
    http_response_code(404);
    echo "Driving Care APK not found on server.";
}
