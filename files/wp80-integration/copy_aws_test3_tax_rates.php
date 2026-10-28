<?php
/** Copy the existing local tax baseline into only the isolated AWS validation site. */
function gbc_copy_source_tax_rates_to_aws_site(int $destination): array
{
    global $wpdb;
    $source = get_site(5); $target = get_site($destination);
    if (DB_NAME !== 'wp-only1-multi-php85-integration' || !$source || !$target
        || $source->domain !== 'localhost-wp-only1-multi' || $source->path !== '/gbc-pilot/'
        || $target->domain !== 'localhost-wp-only1-multi' || $target->path !== '/gbc-aws-test3/'
        || $destination === 5) { throw new RuntimeException('Unexpected site or database.'); }
    $sourcePrefix = $wpdb->get_blog_prefix(5);
    $targetPrefix = $wpdb->get_blog_prefix($destination);
    $rates = $wpdb->get_results("SELECT * FROM {$sourcePrefix}woocommerce_tax_rates ORDER BY tax_rate_id", ARRAY_A);
    $locations = $wpdb->get_results("SELECT * FROM {$sourcePrefix}woocommerce_tax_rate_locations ORDER BY location_id", ARRAY_A);
    if ((int)$wpdb->get_var("SELECT COUNT(*) FROM {$targetPrefix}woocommerce_tax_rates") !== 0
        || (int)$wpdb->get_var("SELECT COUNT(*) FROM {$targetPrefix}woocommerce_tax_rate_locations") !== 0) {
        throw new RuntimeException('Destination tax data already exists; refused overwrite.');
    }
    $sourceHash = hash('sha256', serialize([$rates, $locations]));
    switch_to_blog($destination);
    $wpdb->query('START TRANSACTION');
    try {
        $ids = [];
        foreach ($rates as $rate) {
            $oldId = $rate['tax_rate_id']; unset($rate['tax_rate_id']);
            $newId = WC_Tax::_insert_tax_rate($rate);
            if (!$newId || $wpdb->last_error !== '') { throw new RuntimeException('Tax insertion failed.'); }
            $ids[$oldId] = $newId;
        }
        foreach ($locations as $location) {
            unset($location['location_id']);
            if (!isset($ids[$location['tax_rate_id']])) { throw new RuntimeException('Unknown source rate.'); }
            $location['tax_rate_id'] = $ids[$location['tax_rate_id']];
            if ($wpdb->insert($targetPrefix.'woocommerce_tax_rate_locations', $location) === false) {
                throw new RuntimeException('Tax location insertion failed.');
            }
        }
        // Compare every copied business field, ignoring only generated primary keys.
        $copied = $wpdb->get_results("SELECT * FROM {$targetPrefix}woocommerce_tax_rates ORDER BY tax_rate_id", ARRAY_A);
        $normalize = static function (array $rows): array {
            return array_map(static function (array $row): array { unset($row['tax_rate_id']); return $row; }, $rows);
        };
        if ($normalize($copied) !== $normalize($rates)) { throw new RuntimeException('Copied rates differ.'); }
        $afterRates = $wpdb->get_results("SELECT * FROM {$sourcePrefix}woocommerce_tax_rates ORDER BY tax_rate_id", ARRAY_A);
        $afterLocations = $wpdb->get_results("SELECT * FROM {$sourcePrefix}woocommerce_tax_rate_locations ORDER BY location_id", ARRAY_A);
        if ($sourceHash !== hash('sha256', serialize([$afterRates, $afterLocations]))) {
            throw new RuntimeException('Source tax data differs.');
        }
        $wpdb->query('COMMIT');
        WC_Cache_Helper::invalidate_cache_group('taxes');
        return ['source_site'=>5,'target_site'=>$destination,'rates_copied'=>count($rates),
            'locations_copied'=>count($locations),'source_unchanged'=>true];
    } catch (Throwable $error) {
        $wpdb->query('ROLLBACK'); throw $error;
    } finally { restore_current_blog(); }
}
