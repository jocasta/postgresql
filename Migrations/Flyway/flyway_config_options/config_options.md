
### Flyway Config Options

<details>
<summary>baseLineoOnMigrate</summary>

# 🔹 What “baseline” Actually Means

Baseline tells Flyway:

> “This database already exists. Start version tracking from here — don’t try to recreate everything.”

It is used when:

* You already have a live database
* You’re introducing Flyway after the fact
* You **do not** want Flyway to run your old V1/V2 scripts

---

# 🔹 `flyway.baselineOnMigrate`

### What it does

**If**:

* The database has objects
* But the `flyway_schema_history` table does not exist

**Then Flyway will**:

1. Create the history table
2. Insert a row marking the database as already at a given baseline version
3. Skip all migrations ≤ baseline version

Without this setting, Flyway will fail with:

```
Found non-empty schema(s) but no schema history table.
Use baseline() or set baselineOnMigrate to true.
```

---

# 🔹 `flyway.baselineVersion`

This defines the version Flyway will mark as “already applied”.

Default:

```
1
```

But you can change it:

```
flyway.baselineVersion=100
```

---

# 🔹 Example Scenario (Very Realistic)

You have an existing production DB.

Your repo contains:

```
V1__Create_tables.sql
V2__Add_indexes.sql
V3__Add_new_feature.sql
```

But prod already has all of this.

If you just run:

```
flyway migrate
```

Flyway will panic because:

* DB is not empty
* No history table exists

So instead:

```
flyway.baselineOnMigrate=true
flyway.baselineVersion=3
```

Now when you run `migrate`, Flyway:

* Creates `flyway_schema_history`
* Inserts baseline entry at version 3
* Will only run future migrations like `V4__...`

---

# 🔹 What Gets Inserted

The history table will contain something like:

| version | description | type     |
| ------- | ----------- | -------- |
| 3       | Baseline    | BASELINE |

That’s it.

---

# 🔹 When You Should Use It

✅ Introducing Flyway to an existing DB
✅ Migrating legacy system to managed schema control
✅ You manually verified DB matches repo up to version X

---

# 🔹 When You Should NOT Use It

❌ On a brand new empty database
❌ To “skip errors”
❌ As a workaround for broken migrations

It’s not a band-aid. It’s a controlled starting line.

---

# 🔹 Important Subtlety

Baseline does NOT run your migrations.

It only marks them as already applied.

So if your database does NOT actually match the version you baseline to, you just created schema drift.

That’s on you.

---

# 🔹 Your Likely Setup (Local Docker)

If you're starting fresh:

You do NOT need baseline at all.

Just:

```
flyway migrate
```

Let it create everything from V1 upward.

---

# 🔹 Clean Mental Model

Think of baseline like:

> “We are starting version control from chapter 5 because chapters 1–4 were written before Git existed.”

---

</details>
<!-- END OF BaseLineOnMigrate -->