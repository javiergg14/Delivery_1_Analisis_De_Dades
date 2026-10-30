<?php
// Recibe session_id y end_date. Guarda la hora de fin de la sesion.
include 'config.php';

$session_id = (int)$_POST['session_id'];
$end_date = $_POST['end_date'];

$sql = "UPDATE sessions SET end_date = '$end_date' WHERE session_id = $session_id";

if ($conn->query($sql) === TRUE) {
  echo "OK";
} else {
  echo "Error: " . $sql . "<br>" . $conn->error;
}

$conn->close();
?>
