<?php
// 2026-10-27 migration validation: create only a new site in the isolated local DB.
error_reporting(E_ALL & ~E_DEPRECATED); ini_set('display_errors', '0');
$_SERVER['REMOTE_ADDR']='127.0.0.1';
$_SERVER['HTTP_HOST']='localhost-wp-only1-multi';
$_SERVER['REQUEST_URI']='/gbc-pilot/'; $_SERVER['SERVER_PROTOCOL']='HTTP/1.1';
$_SERVER['HTTPS']='on'; $_SERVER['SERVER_PORT']=443;
define('WP_USE_THEMES', false);
try {
require '/var/www/html/wp-only1-multi/wp-load.php';
if (DB_NAME !== 'wp-only1-multi-php85-integration') { throw new RuntimeException(); }
$private=json_decode(file_get_contents('/tmp/gbc-aws-test3-private.json'),true);
if (!is_array($private) || $private['gbc_host']!=='https://gbc-pilot-test.goodbet.jp'
    || $private['partner']!=='ishikuni' || $private['wc_product_id']!==181) { throw new RuntimeException(); }
if (get_blog_id_from_url('localhost-wp-only1-multi','/gbc-aws-test3/')) {
    echo json_encode(['created'=>false,'reason'=>'site_already_exists']); exit(2);
}
switch_to_blog(5);
$before=['integration_options_sha256'=>hash('sha256',serialize(get_option('only1-integration-woocommerce'))),
    'product5_metadata_sha256'=>hash('sha256',serialize(get_post_meta(5))),
    'home'=>get_option('home')];
$opts=get_option('only1-integration-woocommerce');
if (!is_array($opts)) { throw new RuntimeException(); }
$admins=get_users(['blog_id'=>5,'role'=>'administrator','fields'=>'ID','number'=>1]);
if (!$admins) { throw new RuntimeException(); }
$template=get_option('template'); $stylesheet=get_option('stylesheet');
$mods=get_option('theme_mods_'.$stylesheet); $permalinks=get_option('permalink_structure');
$settings=[];
foreach (['woocommerce_currency','woocommerce_currency_pos','woocommerce_price_num_decimals',
    'woocommerce_price_decimal_sep','woocommerce_price_thousand_sep','woocommerce_calc_taxes',
    'woocommerce_prices_include_tax','woocommerce_default_country','woocommerce_tax_based_on',
    'woocommerce_tax_display_shop','woocommerce_tax_display_cart'] as $key) { $settings[$key]=get_option($key); }
$blog=wpmu_create_blog('localhost-wp-only1-multi','/gbc-aws-test3/',
    'GBC AWS test-3 validation',(int)$admins[0],['public'=>0],1);
if (is_wp_error($blog)) { throw new RuntimeException(); }
// Deliberately use only the two plugins needed by this site. Existing sites keep their own list.
switch_to_blog($blog);
update_option('active_plugins',['woocommerce/woocommerce.php',
    'wp-only1-integration-woocommerce-plugin-aws-test3/wp-only1-integration-woocommerce-plugin.php']);
update_option('template',$template); update_option('stylesheet',$stylesheet);
if (is_array($mods)) { update_option('theme_mods_'.$stylesheet,$mods); }
update_option('home','https://localhost-wp-only1-multi/gbc-aws-test3');
update_option('siteurl','https://localhost-wp-only1-multi/gbc-aws-test3');
update_option('blog_public',0);
update_option('permalink_structure',$permalinks);
WC_Install::install(); WC_Install::create_pages();
foreach ($settings as $key=>$value) { update_option($key,$value); }
$opts['custom_site_host']=$private['gbc_host']; $opts['partner_slug']=$private['partner'];
$opts['use_gbc_third']=1; $opts['api_key']=$private['api_key'];
update_option('only1-integration-woocommerce',$opts);
if (get_post(181)) { throw new RuntimeException(); }
$id=wp_insert_post(['import_id'=>181,'post_type'=>'product','post_status'=>'publish',
    'post_title'=>'PHP85 AWS test-3 watch belt','post_name'=>'php85-aws-test3-watch-belt'],true);
if (is_wp_error($id) || $id!==181) { throw new RuntimeException(); }
$product=new WC_Product_Simple($id);
$product->set_regular_price((string)$private['price']); $product->set_price((string)$private['price']);
$product->set_stock_status('instock'); $product->set_catalog_visibility('hidden');
$product->set_sku('php85-aws-test3-174');
$product->update_meta_data('only1_custom_product_code',$private['product_slug']);
$product->save();
$GLOBALS['wp_rewrite']->init(); flush_rewrite_rules(false);
$result=['created'=>true,'db'=>DB_NAME,'blog_id'=>(int)$blog,'product_id'=>$id,
    'product_url'=>get_permalink($id),'cart_url'=>wc_get_cart_url(),
    'gbc_host'=>$private['gbc_host'],'gbc_product_id'=>174,'partner'=>$private['partner'],
    'product_slug'=>$private['product_slug'],'source_blog5_before'=>$before];
switch_to_blog(5);
$result['source_blog5_unchanged']=$before['integration_options_sha256']===hash('sha256',serialize(get_option('only1-integration-woocommerce')))
    && $before['product5_metadata_sha256']===hash('sha256',serialize(get_post_meta(5))) && $before['home']===get_option('home');
if (!$result['source_blog5_unchanged']) { throw new RuntimeException(); }
echo json_encode($result,JSON_UNESCAPED_SLASHES).PHP_EOL;
} catch (Throwable $e) {
    // Plugin exceptions may include request headers. Never return their message.
    echo json_encode(['created'=>false,'exception_class'=>get_class($e)]).PHP_EOL; exit(1);
}
