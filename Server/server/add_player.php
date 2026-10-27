<?php
// Recibe: name, country, age, gender, join_date  ->  devuelve player_id
require_once __DIR__ . '/common.php';
require_post();

$name    = post_str('name');
$country = post_str('country');
$age     = post_int('age');
$gender  = (float)post_str('gender');
$join    = post_date('join_date');

$conn = db();

// Pais: se inserta si no existe y LAST_INSERT_ID devuelve su id en ambos casos.
$stmt = $conn->prepare(
    'INSERT INTO countries (name) VALUES (?)
     ON DUPLICATE KEY UPDATE country_id = LAST_INSERT_ID(country_id)'
);
$stmt->bind_param('s', $country);
$stmt->execute();
$countryId = $conn->insert_id;
$stmt->close();

$stmt = $conn->prepare(
    'INSERT INTO players (name, country_id, age, gender, join_date) VALUES (?, ?, ?, ?, ?)'
);
$stmt->bind_param('siids', $name, $countryId, $age, $gender, $join);
$stmt->execute();
echo $conn->insert_id;
