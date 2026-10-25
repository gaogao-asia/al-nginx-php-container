<?php
error_reporting(E_ALL & ~E_DEPRECATED); ini_set('display_errors', '0');
$_SERVER['HTTP_HOST']='localhost-wp-only1-multi';
$_SERVER['REQUEST_URI']='/gbc-pilot/';
$_SERVER['SERVER_PROTOCOL']='HTTP/1.1';
$_SERVER['HTTPS']='on'; $_SERVER['SERVER_PORT']=443;
define('WP_USE_THEMES', false);
require '/var/www/html/wp-only1-multi/wp-load.php';
if (DB_NAME !== 'wp-only1-multi-php85-integration') { throw new RuntimeException('Wrong DB'); }
switch_to_blog(5);
$product=get_post(5);
if (!$product || $product->post_name !== 'wallet-n1' || $product->post_type !== 'product') { throw new RuntimeException('Wrong product'); }
$opts=get_option('only1-integration-woocommerce');
if (!is_array($opts)) { throw new RuntimeException('Settings missing'); }
$before=['host'=>$opts['custom_site_host'] ?? null,'partner'=>$opts['partner_slug'] ?? null,'product_code'=>get_post_meta(5,'only1_custom_product_code',true),'home'=>get_option('home'),'siteurl'=>get_option('siteurl')];
$opts['custom_site_host']='https://localhost-gbc-pilot';
$opts['partner_slug']='standfield';
$opts['use_gbc_third']=1;
update_option('only1-integration-woocommerce',$opts);
update_post_meta(5,'only1_custom_product_code','wallet-n1-6');
update_option('home','https://localhost-wp-only1-multi/gbc-pilot');
update_option('siteurl','https://localhost-wp-only1-multi/gbc-pilot');
// Prevent HTTP canonical redirects at the multisite root as well.
switch_to_blog(1);
update_option('home','https://localhost-wp-only1-multi');
update_option('siteurl','https://localhost-wp-only1-multi');
switch_to_blog(5);
$blocked=wp_remote_get('https://example.com/');
echo json_encode(['db'=>DB_NAME,'blog'=>get_current_blog_id(),'product'=>5,'before'=>$before,'after'=>['host'=>$opts['custom_site_host'],'partner'=>$opts['partner_slug'],'product_code'=>get_post_meta(5,'only1_custom_product_code',true),'home'=>get_option('home'),'siteurl'=>get_option('siteurl')],'mail_intercepted'=>apply_filters('pre_wp_mail',null,[])===true,'external_http_blocked'=>is_wp_error($blocked) && $blocked->get_error_code()==='integration_external_http_blocked','async_runner_disabled'=>apply_filters('action_scheduler_allow_async_request_runner',true)===false],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";
