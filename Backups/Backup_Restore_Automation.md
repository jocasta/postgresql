### Backup Corruption in PostgreSQL — The Disaster You Only Discover During Recovery

The database went down at 3:12 AM.

Nothing unusual. Hardware failures happen. The fix should have been routine: restore the PostgreSQL backup and move on.

Except the restore failed.

So did the previous backup.
And the one before that.

The backups existed. Cron jobs had been green for months. Storage looked “healthy.”
But when recovery actually mattered, every usable backup was already corrupted.

This is the PostgreSQL failure most teams never test for.

<hr>

## Why PostgreSQL Backup Corruption Is Almost Always Silent
PostgreSQL backup tools (`pg_dump`, `pg_basebackup`) are reliable—but they are not corruption detectors. They assume the data read from disk is correct.

In real production systems, corruption usually originates outside PostgreSQL:

* Degrading disks or RAID controllers returning incorrect data
* Filesystems silently dropping or reordering writes
* Network issues during backup transfer
* Storage acknowledging writes that never fully completed

None of these necessarily cause backup jobs to fail.
So teams end up with backups that look valid but cannot be restored.

<hr>

## Bad vs Good Practice (What Actually Breaks vs What Actually Works)

❌ **Bad Practice #1 — “Backup Job Succeeded = Backup Is Safe”**

* Cron exits with code 0
* Backup file exists
* No alerts triggered

**Why this fails**
Backup tools trust the storage layer. Silent corruption passes through unnoticed and surfaces only during restore — when it’s already too late.

✅ **Good Practice #1 — Automated Restore Testing (Non-Negotiable)**

A backup that has never been restored is unverified data.

**Minimum viable practice**

* Restore at least one backup per day
* Use an isolated database
* Let PostgreSQL actually read the data

```sql
createdb restore_test
pg_restore -d restore_test /backups/latest.dump || exit 1
psql restore_test -c "SELECT count(*) FROM pg_class;"
dropdb restore_test
```

If this fails, your backups are already broken — and you still have time to act.

<hr>

❌ **Bad Practice #2 — “We Trust Our Storage”**

* RAID reports healthy
* SMART looks fine
* No filesystem errors

**Why this fails**
Silent corruption is often progressive. Hardware can lie convincingly until it doesn’t.

✅ **Good Practice #2 — Checksums for Every Backup File**

PostgreSQL data checksums protect the database — not your backup artifacts.

Generate cryptographic checksums immediately after backup:

```sh
pg_dump -Fc mydb > backup.dump
sha256sum backup.dump > backup.dump.sha256
```

Verify:

* Before any restore
* Periodically (daily or weekly)

Checksum mismatches are early warnings, not disasters.

<hr>

❌ **Bad Practice #3 — Ignoring Backup Size Drift**

* Backups stored and forgotten
* No historical comparison

**Why this fails**

Corruption is often gradual. Truncation and incomplete writes frequently show up first as size anomalies.

✅ **Good Practice #3 — Monitor Backup Size Consistency**

Track backup sizes and alert when size deviates ±25–30% without schema or data changes.

This catches:

* Partial backups
* Compression failures
* Storage write issues

Simple metric. Large payoff.

<hr> 

❌ **Bad Practice #4 — No Physical Standby**

* Single PostgreSQL node
* WAL integrity never exercised

**Why this fails**

You only test WAL integrity months later — during a restore.

✅ **Good Practice #4 — Physical Standby as a Canary**

A physical standby applying WAL continuously is a live integrity test.
If WAL is corrupted, replication breaks immediately — days or weeks before restore day.

Replication does not replace backups.
It dramatically reduces unpleasant surprises.

<hr>

## What a Real Backup Validation Setup Looks Like

Teams that rarely lose data typically do all four:

* Daily restore tests (automated)
* Checksums for every backup
* Backup size & readability monitoring
* At least one physical standby

None of these are exotic.
They are boring, repeatable — and effective.

## The Practical Bottom Line

Most PostgreSQL backup disasters aren’t caused by missing backups.
They’re caused by untested backups.

If your confidence comes from green dashboards, successful cron jobs, and files existing on disk, you’re trusting assumptions — not evidence.

**The only backup that matters is one you’ve restored before disaster day.**

Test it now.

Because when the phone rings at 3 AM, it’s already too late to start validating.

