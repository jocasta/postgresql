-- Column names vary slightly by CUR schema. 
-- If yours uses slashes, quote them (`line_item/usage_type`). 
-- Use DESCRIBE your_cur_table in Athena to confirm names.

-- You can add dimensions like DBClusterIdentifier if you enforce tagging 
-- (e.g., tag clusters with user:cluster and use that tag in SELECT). 
-- Tag columns come through as resourceTags/user:<TagKey> once activated

CREATE OR REPLACE VIEW finops_rds_daily AS
SELECT
  date_trunc('day', from_iso8601_timestamp(`line_item/usage_start_date`))         AS day,
  `line_item/usage_account_id`                                                   AS account_id,
  COALESCE(`product/region`, `product/region_code`)                              AS region,
  -- example tag column (must be activated in Billing first):
  `resourceTags/user:env`                                                        AS env,
  CASE
    -- Compute (provisioned instances)
    WHEN regexp_like(`line_item/usage_type`, '^RDS:InstanceUsage') THEN 'compute'
    -- Compute (Aurora Serverless v2: ACU-hours)
    WHEN regexp_like(`line_item/usage_type`, '^Aurora:ServerlessUsage') THEN 'compute'
    -- Storage (cluster/instance storage)
    WHEN regexp_like(`line_item/usage_type`, 'Storage(Usage|$)') OR
         regexp_like(`product/product_family`, 'Database Storage') THEN 'storage'
    -- I/O (Aurora Standard only; not present on I/O-Optimized)
    WHEN regexp_like(`line_item/usage_type`, '^Aurora:StorageIOUsage') THEN 'io'
    -- Backups / snapshots
    WHEN regexp_like(`line_item/usage_type`, 'Backup(Usage|)$|Snapshot') OR
         regexp_like(`product/product_family`, 'Backup Storage') THEN 'backup'
    -- Provisioned IOPS (gp3/io1 add-ons for RDS MySQL/Postgres)
    WHEN regexp_like(`line_item/usage_type`, 'IOPS') THEN 'provisioned_iops'
    ELSE 'other'
  END AS component,
  SUM(CAST(`line_item/unblended_cost` AS double))                                AS cost_unblended_usd
  -- If you use RIs/SPs and want true cost, switch to amortized:
  -- ,SUM(CAST(coalesce(`pricing/public_on_demand_cost`, `line_item/unblended_cost`) 
  --      + coalesce(`reservation/amortized_upfront_fee_for_billing_period`,0) 
  --      + coalesce(`savingsPlan/savings_plan_effective_cost`,0) AS double))   AS cost_amortized_usd
FROM your_cur_db.your_cur_table
WHERE from_iso8601_timestamp(`line_item/usage_start_date`) >= timestamp '2024-01-01 00:00:00'
  AND `line_item/line_item_type` IN ('Usage','DiscountedUsage')
  AND `product/product_name` IN ('Amazon Relational Database Service','Amazon Aurora')
GROUP BY 1,2,3,4,5;
