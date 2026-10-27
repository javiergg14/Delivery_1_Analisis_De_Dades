<?php
// Recibe: session_id, end_date  ->  cierra la sesion
require_once __DIR__ . '/common.php';
require_post();

$sessionId = post_int('session_id');
$end       = post_date('end_date');

$conn = db();
$stmt = $conn->prepare('UPDATE sessions SET end_date = ? WHERE session_id = ?');
$stmt->bind_param('si', $end, $sessionId);
$stmt->execute();
echo 'OK';
