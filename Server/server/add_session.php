<?php
// Recibe player_id y start_date. Devuelve el id de la sesion.
include 'config.php';

$player_id = (int)$_POST['player_id'];
$start_date = $_POST['start_date'];

$sql = "INSERT INTO sessions (player_id, start_date)
VALUES ($player_id, '$start_date')";

if ($conn->query($sql) === TRUE) {
  echo $conn->insert_id;
} else {
  echo "Error: " . $sql . "<br>" . $conn->error;
}

$conn->close();
?>
