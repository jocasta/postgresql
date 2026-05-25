
-- SHOW SUBSCRIPTION TABLES

SELECT 
    s.subname AS subscription_name,
    n.nspname AS schema_name,
    c.relname AS table_name,
    sr.srsubstate AS state_code,
    CASE sr.srsubstate
        WHEN 'i' THEN 'initialize'
        WHEN 'd' THEN 'data copy'
        WHEN 's' THEN 'synchronized'
        WHEN 'r' THEN 'ready (normal)'
        ELSE 'unknown'
    END AS sync_status
FROM pg_subscription_rel sr
JOIN pg_subscription s ON s.oid = sr.srsubid
JOIN pg_class c ON c.oid = sr.srrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
ORDER BY sync_status, table_name;


--          subscription_name         |  schema_name   |           table_name           | state_code |  sync_status   
-- -----------------------------------+----------------+--------------------------------+------------+----------------
--  osmm_archiving_datawarehouse_prod | osmm_archiving | a_boundaryline                 | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | a_cartographicsymbol           | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | a_cartographictext             | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | a_topographicarea              | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | a_topographicline              | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | a_topographicpoint             | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | boundaryline                   | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | cartographicsymbol             | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | cartographictext               | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | report_event                   | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | report_event_type              | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_applicationform     | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_applicationtype     | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_assign              | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_case                | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_casecharacteristics | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_lrs                 | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_property            | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_qadatapoint         | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_qafailure           | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_qafailurereason     | r          | ready (normal)
--  cmsreports_prd                    | pegareports    | ros_report_rejection           | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | topographicarea                | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | topographicline                | r          | ready (normal)
--  osmm_archiving_datawarehouse_prod | osmm_archiving | topographicpoint               | r          | ready (normal)
