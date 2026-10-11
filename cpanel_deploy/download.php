<?php
$file = __DIR__ . '/Driving_Care_v2.3.apk';
if (file_exists($file)) {
    header('Content-Description: File Transfer');
    header('Content-Type: application/vnd.android.package-archive');
    header('Content-Disposition: attachment; filename="Driving_Care_v2.3.apk"');
    header('Content-Transfer-Encoding: binary');
    header('Expires: 0');
    header('Cache-Control: no-cache, no-store, must-revalidate');
    header('Pragma: no-cache');
    header('Content-Length: ' . filesize($file));
    ob_clean();
    flush();
    readfile($file);
    exit;
} else {
    http_response_code(404);
    echo "File not found";
}
