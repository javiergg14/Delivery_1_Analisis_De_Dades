<?php
// Recibe name, country, age, gender y join_date. Devuelve el id del jugador.
include 'config.php';

$name = $conn->real_escape_string($_POST['name']);
$country = $conn->real_escape_string($_POST['country']);
$age = (int)$_POST['age'];
$gender = (float)$_POST['gender'];
$join_date = $_POST['join_date'];

// Buscamos el pais; si no existe todavia, lo creamos
$result = $conn->query("SELECT country_id FROM countries WHERE name = '$country'");
if ($result->num_rows > 0) {
  $row = $result->fetch_assoc();
  $country_id = $row['country_id'];
} else {
  $conn->query("INSERT INTO countries (name) VALUES ('$country')");
  $country_id = $conn->insert_id;
}

$sql = "INSERT INTO players (name, country_id, age, gender, join_date)
VALUES ('$name', $country_id, $age, $gender, '$join_date')";

if ($conn->query($sql) === TRUE) {
  echo $conn->insert_id;
} else {
  echo "Error: " . $sql . "<br>" . $conn->error;
}

$conn->close();
?>
