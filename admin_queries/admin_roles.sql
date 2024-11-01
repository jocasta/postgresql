-- THIS WILL SHOW ALL NON SYSTEM ROLES
-- AND THEIR ROLE MEMBERS

CREATE OR REPLACE FUNCTION public.admin_roles()
RETURNS TABLE(
    role_name TEXT,
    member_of_roles TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.rolname::TEXT AS role_name,  -- Explicitly cast to TEXT
           ARRAY_AGG(g.rolname::TEXT) AS member_of_roles  -- Explicitly cast to TEXT[]
    FROM pg_roles AS r
    LEFT JOIN pg_auth_members AS m ON r.oid = m.member
    LEFT JOIN pg_roles AS g ON m.roleid = g.oid
    WHERE r.rolname not like ('pg_%')
    AND r.rolname not like ('rds%')
    GROUP BY r.rolname
    ORDER BY r.rolname;
END;
$$ LANGUAGE plpgsql;



-- SELECT                       
--     r.rolname AS role_name,
--     ARRAY_AGG(m.rolname) AS member_of_roles,
--     r.rolsuper AS is_superuser,
--     r.rolinherit AS can_inherit,
--     r.rolcreaterole AS can_create_role,
--     r.rolcreatedb AS can_create_db,
--     r.rolcanlogin AS can_login,
--     r.rolreplication AS can_replication,
--     r.rolbypassrls AS can_bypass_rls
-- FROM
--     pg_roles AS r
--     LEFT JOIN pg_auth_members AS am ON r.oid = am.member
--     LEFT JOIN pg_roles AS m ON am.roleid = m.oid
-- GROUP BY
--     r.rolname,
--     r.rolsuper,
--     r.rolinherit,
--     r.rolcreaterole,
--     r.rolcreatedb,
--     r.rolcanlogin,
--     r.rolreplication,
--     r.rolbypassrls
-- ORDER BY
--     r.rolname;