<?php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json');

// FIX C: Purana server activation flow band. Server activation ka faisla nahi karega.
// Sirf offline cryptographically signed (DCS-) keys allowed hain.
http_response_code(403);
echo json_encode([
    'success' => false,
    'error' => 'activation_deprecated',
    'message' => 'Direct server activation band hai. Activation sirf cryptographically signed (DCS-) keys se allowed hai.'
]);
