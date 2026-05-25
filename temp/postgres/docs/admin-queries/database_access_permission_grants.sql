WITH acl AS (
  SELECT
    d.datname,
    unnest(d.datacl::text[]) AS aclitem_txt
  FROM pg_database d
  --WHERE d.datname = 'data_warehouse'
    where d.datacl IS NOT NULL
),
parsed AS (
  SELECT
    datname,
    CASE
      WHEN split_part(aclitem_txt, '=', 1) = '' THEN 'PUBLIC'
      ELSE quote_ident(split_part(aclitem_txt, '=', 1))
    END AS grantee,
    split_part(split_part(aclitem_txt, '=', 2), '/', 1) AS privletters
  FROM acl
),
letters AS (
  SELECT
    datname,
    grantee,
    unnest(string_to_array(regexp_replace(privletters, '\*', '', 'g'), '')) AS letter
  FROM parsed
)
SELECT DISTINCT
  format(
    'GRANT %s ON DATABASE %I TO %s;',
    CASE letter
      WHEN 'c' THEN 'CONNECT'
      WHEN 'T' THEN 'TEMPORARY'
      WHEN 'C' THEN 'CREATE'
    END,
    datname,
    grantee
  ) AS grant_sql
FROM letters
WHERE letter IN ('c','T','C') ;