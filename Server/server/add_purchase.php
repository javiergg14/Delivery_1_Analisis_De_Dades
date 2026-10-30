<?php
// Recibe session_id, item_id y purchase_date. Devuelve el id de la compra.
include 'config.php';

$session_id = (int)$_POST['session_id'];
$item_id = (int)$_POST['item_id'];
$purchase_date = $_POST['purchase_date'];

$sql = "INSERT INTO purchases (session_id, item_id, purchase_date)
VALUES ($session_id, $item_id, '$purchase_date')";

if ($conn->query($sql) === TRUE) {
  echo $conn->insert_id;
} else {
  echo "Error: " . $sql . "<br>" . $conn->error;
}

$conn->close();
?>
