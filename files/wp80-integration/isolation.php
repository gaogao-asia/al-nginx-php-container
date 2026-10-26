<?php
/** Local integration copy only: isolate mail, HTTP and background work. */
if (!defined('ABSPATH')) { exit; }
add_filter('pre_wp_mail', function () { return true; }, PHP_INT_MAX);
add_filter('action_scheduler_allow_async_request_runner', '__return_false', PHP_INT_MAX);
add_filter('automatic_updater_disabled', '__return_true', PHP_INT_MAX);
// The login language selector fetches translation metadata from WordPress.org.
// Keep the configured locale and avoid that unnecessary request in this isolated copy.
add_filter('login_display_language_dropdown', '__return_false', PHP_INT_MAX);
add_filter('pre_http_request', function ($result, $args, $url) {
    $host = strtolower((string) parse_url($url, PHP_URL_HOST));
    if (!in_array($host, ['localhost-gbc-pilot', 'localhost-wp-only1-multi'], true)) {
        return new WP_Error('integration_external_http_blocked', 'External HTTP is disabled in the integration copy.');
    }
    return $result;
}, PHP_INT_MAX, 3);
add_filter('http_request_args', function ($args) {
    $args['sslverify'] = true;
    $args['sslcertificates'] = '/etc/pki/tls/certs/ca-bundle.crt';
    return $args;
}, PHP_INT_MAX);
