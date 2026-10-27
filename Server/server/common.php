<?php
/**
 * Utilidades compartidas por los endpoints.
 * - Conexion mysqli con excepciones activadas.
 * - Validacion de parametros POST.
 * - Respuesta minima: un entero (el id) o un codigo de error HTTP.
 */
require_once __DIR__ . '/config.php';

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

function db(): mysqli
{
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    $conn->set_charset('utf8mb4');
    return $conn;
}

function fail(int $code, string $msg): void
{
    http_response_code($code);
    echo $msg;
    exit;
}

/** Devuelve $_POST[$key] o corta con 400 si falta. */
function post_str(string $key): string
{
    if (!isset($_POST[$key]) || $_POST[$key] === '') {
        fail(400, "missing $key");
    }
    return trim($_POST[$key]);
}

function post_int(string $key): int
{
    $v = post_str($key);
    if (!ctype_digit($v)) {
        fail(400, "invalid $key");
    }
    return (int)$v;
}

/** Fecha 'Y-m-d H:i:s' validada. */
function post_date(string $key): string
{
    $v = post_str($key);
    $d = DateTime::createFromFormat('Y-m-d H:i:s', $v);
    if (!$d || $d->format('Y-m-d H:i:s') !== $v) {
        fail(400, "invalid $key");
    }
    return $v;
}

function require_post(): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        fail(405, 'POST only');
    }
}
