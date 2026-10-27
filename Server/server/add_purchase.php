<?php
// Recibe: session_id, item_id, purchase_date  ->  devuelve purchase_id
require_once __DIR__ . '/common.php';
require_post();

$sessionId = post_int('session_id');
$itemId    = post_int('item_id');
$date      = post_date('purchase_date');

$conn = db();
$stmt = $conn->prepare(
    'INSERT INTO purchases (session_id, item_id, purchase_date) VALUES (?, ?, ?)'
);
$stmt->bind_param('iis', $sessionId, $itemId, $date);
$stmt->execute();
echo $conn->insert_id;
