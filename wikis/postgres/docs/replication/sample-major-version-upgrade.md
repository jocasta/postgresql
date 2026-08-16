
# Migration Pathway for PEGA CMS (Team Mercury)

## (1) Deploy New Server

Decide on deployment model:
- [Ansible install for PostgreSQL](https://confluence.ros.gov.uk/display/DDteam/PostgreSQL+as+a+Service+-+Ansible+Deploy)

### Full Stack Ansible Deploy (New VM)
```bash
$ ansible-playbook playbooks/postgres_primary.yml -i inventory/postgres_prodev \
--ask-vault-pass \
-e "target=em-vrgi-pgrd77.prodev.ros.gov.uk dbenv=Prodev dbservice=CMS dbteam=Mercury"  \
-t "install, primary, pgbadger, telegraf, barman"
```

### Side-by-Side Ansible Deploy (Different Port)
```bash
$ ansible-playbook playbooks/postgres_primary.yml -i inventory/postgres_Prodev \
-e "target=em-vrgi-pgrd77.prodev.ros.gov.uk dbenv=Prodev pg_ver=14 pg_port=5444 \
-t "install, primary"
```

---

## (2) Update PostgreSQL Configuration

Ensure logical replication is allowed in `postgresql.conf` on both servers. Check/set the following configurations:
- Also make the change on the REPLICA if required

```bash
wal_level = logical
max_replication_slots = 600
max_wal_senders = 10
max_worker_processes = 16
max_parallel_workers_per_gather = 1
max_parallel_workers = 2
max_parallel_maintenance_workers = 1
```

Additionally, change the log directory on the source server.

```bash
# Create log dir
$ mkdir /log/postgres/11  # as user postgres

# Add to source server
log_directory = /log/postgres/11
```

Restart PostgreSQL after making these changes.

---

## (3) Create a Replication Role

Run the following SQL command on the source server:

```sql
-- CREATE REPLICATION USER
CREATE ROLE replication_user_test WITH LOGIN REPLICATION PASSWORD 'your_password';

-- GRANT PERMISSIONS ON SCHEMAS TO REPLICATION USER
GRANT USAGE ON schema pegadata TO replication_user_test;
GRANT USAGE ON schema pegarules TO replication_user_test;
GRANT USAGE ON schema public TO replication_user_test;
GRANT SELECT ON ALL TABLES IN SCHEMA pegadata TO replication_user_test;
GRANT SELECT ON ALL TABLES IN SCHEMA pegarules TO replication_user_test;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO replication_user_test;
```

Replace `'your_password'` with a strong, secure password.

---

## (4) Configure `pg_hba.conf`

In `pg_hba.conf` on the source server, add an entry to allow the destination server to connect.

If running side by side (different ports):
```
local   all   replication_user    trust
```

If running on separate hosts (same port):
```
host replication replication_user destination_server_ip/32 trust
hostssl all all destination_server_ip/32 md5
```

Replace `replication_user` and `destination_server_ip` accordingly.

Reload PostgreSQL after making changes to `pg_hba.conf`.

---

## (5) Create PEGA Schema on Destination

Perform the following steps depending on whether the target server is on the same host or different host.

- Either change the .pgsql_profile to point at version 14 or **hard-code** the 14 path like the below examples


####**Same Server (using different port - example 5444)**


(a)  Load globals into Destination:
```
 /usr/pgsql-14/bin/pg_dumpall -g -p 5432 | /usr/pgsql-14/bin/psql -p 5444
```
(b)  Create cms database on destination server **CHECK OWNERSHIP AND CORRECT NAME BEFORE RUNNING** : 
```
create database cms owner cms ;
```
(c)  Create in schema in Destination: 
```
/usr/pgsql-14/bin/pg_dump -v -p 5432 --schema-only cms | /usr/pgsql-14/bin/psql -p 5444 cms
```

#### **Target server is on different  host** 


(a)  Load globals into Destination: 
```
pg_dumpall -g | psql -h es-vrli-pgrd60.ros.local -U rosdba_prod postgres
```
(b)  Create cms database on destination server **CHECK OWNERSHIP AND CORRECT NAME BEFORE RUNNING**: 
```
create database cms owner cms ;
```
(c)  Create schema in destination:  
```
pg_dump -v -p 5432 --schema-only cms | psql -h es-vrli-pgrd60.ros.local -U rosdba_prod cms
```

---

## (6) Create Publication and Subscription

On the source server, create a publication. On the destination server, create a subscription.

**Source Server:**
```sql
-- CREATE PUBLICATION
create publication pub_pega_full_replication for all tables;

-- CONFIRM ALL TABLES ADDED TO PUBLICATION
select * from pg_publication_tables
where pubname = 'pub_pega_full_replication'
order by schemaname, tablename;
```

**Target Server:**
```sql
-- TARGET ON DIFFERENT HOST
-- CREATE SUBSCRIPTION
CREATE SUBSCRIPTION sub_pega_full_replication
CONNECTION 'dbname=cms host=[HOSTNAME] port=5432 user=replication_user_test password=test_rep'
PUBLICATION pub_pega_full_replication;

-- TARGET SERVER IS ON SAME HOST (add host=localhost if it doesn't work first time)
-- CREATE SUBSCRIPTION
CREATE SUBSCRIPTION sub_pega_full_replication
CONNECTION 'dbname=cms port=5432 user=replication_user_test password=test_rep'
PUBLICATION pub_pega_full_replication;
```

---

## (7) Monitor and Troubleshoot

(a) Monitor the replication status using `pg_stat_replication` on the source server and `pg_stat_subscription` on the destination server.

(b) Check the logs at `/log/postgres` for any errors.


---

## (8) Application Switch

The application team will upgrade PEGA against PostgreSQL 11 first.

### Mercury's Steps:
1. Stop Replica
2. Run PEGA upgrade
3. Test if Upgrade was successful

**Side-by-Side Switch Process:**

1. Shutdown application
2. Once replication is in sync, shut down the old DB server
3. Restart the new DB server
4. Start application
5. After confirming the application is working, run cleanup jobs:

   - Disable the old server: `$ systemctl disable postgresql-11`
   - Drop subscription on target server
   - Sync the new server with BARMAN
   - Create new replica using repmgr


**Different Host Switch Process:**
1. Shutdown application
2. Once replication is in sync, shut down the old DB server
3. Restart the new DB server (No need to flip the port as should already be running 5432)
4. Start application (This requires the application to point at the new hostname)
