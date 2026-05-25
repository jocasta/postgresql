SELECT
  $__timeGroup(day, 1d) AS time,
  component,
  SUM(cost_unblended_usd) AS cost
FROM finops_rds_daily
WHERE $__timeFilter(day)
  AND (account_id IN (${account:csv}) OR '${account:csv}' = '')
  AND (env IN (${env:csv}) OR '${env:csv}' = '')
GROUP BY 1, component
ORDER BY 1;