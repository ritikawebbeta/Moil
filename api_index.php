<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Cache-Control, Pragma, Expires');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit(0);
}

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Cache-Control: post-check=0, pre-check=0', false);
header('Pragma: no-cache');
header('Expires: 0');

function isNodeRunning() {
    $connection = @fsockopen('127.0.0.1', 3000, $errno, $errstr, 1);
    if (is_resource($connection)) {
        fclose($connection);
        return true;
    }
    return false;
}

function startNodeBackend() {
    $nodeBin = '/home/u156958239/.nvm/versions/node/v20.20.2/bin/node';
    $backendDir = '/home/u156958239/moil_backend';
    $cmd = "export PATH=/home/u156958239/.nvm/versions/node/v20.20.2/bin:\$PATH && cd {$backendDir} && {$nodeBin} src/app.js > /dev/null 2>&1 &";
    exec($cmd);
}

if (!isNodeRunning()) {
    startNodeBackend();
    usleep(1200000);
}

$requestUri = $_SERVER['REQUEST_URI'];
$cleanPath = parse_url($requestUri, PHP_URL_PATH);
$cleanPath = preg_replace('#^/test/moil_hr_app/api#', '', $cleanPath);
if (empty($cleanPath) || $cleanPath === '/') {
    $cleanPath = '';
}
$queryString = parse_url($requestUri, PHP_URL_QUERY);
$fullPath = '/api' . $cleanPath . ($queryString ? '?' . $queryString : '');

$nodeUrl = 'http://127.0.0.1:3000' . $fullPath;
$rawInput = file_get_contents('php://input');

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $nodeUrl);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $_SERVER['REQUEST_METHOD']);
if (in_array($_SERVER['REQUEST_METHOD'], array('POST', 'PUT', 'PATCH', 'DELETE'))) {
    curl_setopt($ch, CURLOPT_POSTFIELDS, $rawInput);
}

$reqHeaders = array('Content-Type: application/json');
if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
    $reqHeaders[] = 'Authorization: ' . $_SERVER['HTTP_AUTHORIZATION'];
}
if (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
    $reqHeaders[] = 'Authorization: ' . $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
}
curl_setopt($ch, CURLOPT_HTTPHEADER, $reqHeaders);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
curl_setopt($ch, CURLOPT_TIMEOUT, 15);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode && $httpCode >= 200 && $response !== false && strlen($response) > 0) {
    http_response_code($httpCode);
    header('Content-Type: application/json; charset=utf-8');
    echo $response;
    exit(0);
}

if (!isNodeRunning()) {
    startNodeBackend();
    usleep(1200000);
}

$chRetry = curl_init();
curl_setopt($chRetry, CURLOPT_URL, $nodeUrl);
curl_setopt($chRetry, CURLOPT_CUSTOMREQUEST, $_SERVER['REQUEST_METHOD']);
if (in_array($_SERVER['REQUEST_METHOD'], array('POST', 'PUT', 'PATCH', 'DELETE'))) {
    curl_setopt($chRetry, CURLOPT_POSTFIELDS, $rawInput);
}
curl_setopt($chRetry, CURLOPT_HTTPHEADER, $reqHeaders);
curl_setopt($chRetry, CURLOPT_RETURNTRANSFER, true);
curl_setopt($chRetry, CURLOPT_CONNECTTIMEOUT, 3);
curl_setopt($chRetry, CURLOPT_TIMEOUT, 15);

$retryResponse = curl_exec($chRetry);
$retryHttpCode = curl_getinfo($chRetry, CURLINFO_HTTP_CODE);
curl_close($chRetry);

if ($retryHttpCode && $retryHttpCode >= 200 && $retryResponse !== false && strlen($retryResponse) > 0) {
    http_response_code($retryHttpCode);
    header('Content-Type: application/json; charset=utf-8');
    echo $retryResponse;
} else {
    http_response_code(503);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(array(
        'error' => 'Service Unavailable',
        'message' => 'Backend service is starting. Please try again.'
    ));
}
