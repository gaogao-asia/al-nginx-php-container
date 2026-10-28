<?php

$proxyIp = $argv[1] ?? '';
$appRoot = $argv[2] ?? '';
if (!filter_var($proxyIp, FILTER_VALIDATE_IP) || !preg_match('#^/var/www/html/[a-zA-Z0-9_-]+$#', $appRoot)) {
    throw new RuntimeException('Invalid local proxy address or app directory');
}
if (!is_file($appRoot . '/.env') || !is_file($appRoot . '/vendor/autoload.php')) {
    echo "App not installed yet; skipping trusted proxy update\n";
    exit(0);
}
require $appRoot . '/vendor/autoload.php';
$path = $appRoot . '/.env';
$env = file_get_contents($path);
$updated = preg_replace('/^TRUSTED_PROXIES=.*$/m', 'TRUSTED_PROXIES=' . $proxyIp, $env, -1, $count);
if ($count === 0) {
    $updated = rtrim($env) . "\nTRUSTED_PROXIES=" . $proxyIp . "\n";
}
if ($updated !== $env) {
    (new Symfony\Component\Filesystem\Filesystem)->dumpFile($path, $updated);
}
echo "Local trusted proxy synchronized to " . $proxyIp . "\n";
