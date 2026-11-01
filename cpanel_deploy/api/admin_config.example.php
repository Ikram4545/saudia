<?php
// Template configuration file for Driving Care Admin API
// Copy this file to admin_config.php and set strong credentials.
// NEVER commit admin_config.php to source control!

return [
    'username' => 'your_admin_user',
    'password' => 'your_strong_random_password_here',
    'allowed_users' => ['your_admin_user'],
    'secret_salt' => bin2hex(random_bytes(32)),
];
