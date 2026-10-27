# Security

## Roles and privileges required on each side

**Publisher**

| Need | Privilege |
|---|---|
| Connect for replication | `LOGIN` and `REPLICATION` attribute (or a superuser) |
| Initial copy | `SELECT` on every published table, `USAGE` on their schemas |
| Create publication `FOR TABLE` | Owner of the tables (and `CREATE` on the database) |
| Create publication `FOR ALL TABLES` / `TABLES IN SCHEMA` | Superuser |
| Create / drop slots manually | `REPLICATION` attribute |

```sql
CREATE ROLE repl WITH LOGIN REPLICATION PASSWORD '...';
GRANT CONNECT ON DATABASE app TO repl;
GRANT USAGE ON SCHEMA app TO repl;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO repl;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app GRANT SELECT ON TABLES TO repl;
```

!!! warning
    A role with `REPLICATION` can create slots (and so cause WAL retention) and take physical base backups of the **whole cluster**. Treat it as a highly privileged credential; give it its own role, not the application role.

Row-level security: the initial `COPY` fails if RLS is enabled on a table and the replication role doesn't bypass it (`BYPASSRLS` or table owner). Changes streamed after the copy are not filtered by RLS.

**Subscriber**

| Need | Privilege |
|---|---|
| Create subscription | Superuser, or PG 16+: `pg_create_subscription` + `CREATE` on database |
| Apply changes (PG 15 and older) | Subscription owner must be able to write the tables (typically superuser) |
| Apply changes (PG 16+) | Applied **as the table owner**; subscription owner needs `SET ROLE` to each table owner (or `run_as_owner = true`) |

The apply process bypasses normal triggers and permission checks only as far as its role allows. In PG 16+ running as the table owner limits what a malicious publisher could do via crafted changes (e.g. trigger code executed with high privileges).

## pg_hba.conf and authentication for replication connections

A logical replication connection is a connection to a **specific database**:

```text
# TYPE   DATABASE   USER   ADDRESS          METHOD
hostssl  app        repl   10.20.0.0/16     scram-sha-256
```

!!! danger "Common mistake"
    The `replication` keyword in the DATABASE column matches only **physical** replication connections. It does **not** match logical replication. Use the actual database name (or `all`).

Credential options on the subscriber side:

- Password in `CONNECTION` (stored in `pg_subscription.subconninfo`, visible to superusers and in `pg_dump` output of subscriptions).
- `~/.pgpass` for the subscriber's OS user (keeps it out of the catalog; for non-superuser owners requires `password_required = false`, superuser only).
- **Client certificates** (`sslcert`/`sslkey` in the connection string, `cert` method in `pg_hba.conf`).
- Use `scram-sha-256`, not `md5`.

## Row filters and column lists as data-minimisation tools

Publications can deliberately send **less** than the full table:

```sql
-- only EU customers, without personal data columns
CREATE PUBLICATION pub_eu_analytics
    FOR TABLE app.customers (id, country, segment, created_at) WHERE (region = 'EU')
    WITH (publish = 'insert, update, delete');
```

- **Column lists** keep PII (names, emails, addresses, card data) off analytics/reporting replicas.
- **Row filters** restrict data to a tenant, region or legal entity (e.g. data residency).
- The **initial copy** respects both.

Caveats:

- These are publication filters, **not access control**: any role that can create a subscription to a *different* publication, or has `REPLICATION` + `SELECT` on the table, can still get everything. Limit who can create publications and who has `REPLICATION`.
- Replica identity columns are always sent for `UPDATE`/`DELETE`, so don't use a sensitive column as the key if it must be hidden.
- With `REPLICA IDENTITY FULL`, old values of **all** columns are in the WAL (filtered on output, but present on the publisher's disk and visible to other decoding consumers).

## SSL/TLS between publisher and subscriber

Encrypt replication traffic, especially across networks or clouds.

Publisher:

```text
# postgresql.conf
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file  = 'server.key'
ssl_min_protocol_version = 'TLSv1.2'
```

```text
# pg_hba.conf: hostssl forces TLS
hostssl  app  repl  10.20.0.0/16  scram-sha-256
```

Subscriber connection string:

```sql
CREATE SUBSCRIPTION sub_app
    CONNECTION 'host=pub.example.com dbname=app user=repl sslmode=verify-full sslrootcert=/etc/ssl/certs/pub-ca.crt'
    PUBLICATION pub_app;
```

| `sslmode` | Encrypts | Verifies server |
|---|---|---|
| `require` | Yes | No (vulnerable to MITM) |
| `verify-ca` | Yes | CA only |
| `verify-full` | Yes | CA and hostname (**recommended**) |

Verify:

```sql
-- publisher
SELECT s.pid, a.application_name, s.ssl, s.version, s.cipher
FROM pg_stat_ssl s JOIN pg_stat_activity a USING (pid)
WHERE a.backend_type = 'walsender';
```

See also the [SSL](../../ssl/index.md) section.
