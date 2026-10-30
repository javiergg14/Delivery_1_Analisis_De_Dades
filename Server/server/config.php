<?php
$servername = "localhost";
$username = "javiergg16";
$password = "JaGoGo463801@@";
$dbname = "javiergg16";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}
?>
