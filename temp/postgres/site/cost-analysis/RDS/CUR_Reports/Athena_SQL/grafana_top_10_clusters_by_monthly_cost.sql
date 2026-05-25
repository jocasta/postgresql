-- If you expose a user:cluster tag
SELECT
  date_trunc('month', day) AS month,
  `resourceTags/user:cluster` AS cluster,
  SUM(cost_unblended_usd) AS cost
FROM finops_rds_daily
WHERE $__timeFilter(day)
GROUP BY 1,2
ORDER BY month, cost DESC
LIMIT 10;
