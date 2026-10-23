<?php
header('Content-Type: application/json');
echo json_encode([
    'success' => false,
    'error' => 'trial_disabled',
    'message' => 'Trial mode khatam kar diya gaya hai. Sirf paid license key se app activate hogi.'
]);
