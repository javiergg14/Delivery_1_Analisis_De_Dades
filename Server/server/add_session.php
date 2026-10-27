<?php
// Recibe: player_id, start_date  ->  devuelve session_id
require_once __DIR__ . '/common.php';
require_post();

$playerId = post_int('player_id');
$start    = post_date('start_date');

$conn = db();
$stmt = $conn->prepare('INSERT INTO sessions (player_id, start_date) VALUES (?, ?)');
$stmt->bind_param('is', $playerId, $start);
$stmt->execute();
echo $conn->insert_id;
