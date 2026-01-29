When you have a heavy write load, the goal of tuning checkpoints is to **stop the "spikes."** By default, Postgres can be too aggressive, trying to finish a checkpoint as fast as possible, which hog-ties your disk I/O and makes your application lag.

To fix this, you want to make checkpoints **frequent enough to keep recovery fast, but slow enough to be gentle on the disk.**

---

### Summary Table for Heavy Writes

| Parameter | Recommended Value | Impact |
| --- | --- | --- |
| `checkpoint_timeout` | `15min` | Reduces overhead of repeated writes. |
| `max_wal_size` | `16GB` (or more) | Prevents "early" forced checkpoints. |
| `checkpoint_completion_target` | `0.9` | Smooths out the I/O load over time. |
| `min_wal_size` | `4GB` | Keeps some WAL files ready to go (slight speed boost). |

---

### 1. The "Pacing" Settings

These are the most important knobs for heavy write loads.

* **`checkpoint_timeout`**:
* *Default:* 5min.
* *Tuned:* **15min to 30min**.
* *Why:* Increasing this reduces the frequency of checkpoints, meaning less redundant writing of the same data pages.


* **`checkpoint_completion_target`**:
* *Default:* 0.9.
* *Tuned:* **Keep it at 0.9**.
* *Why:* This tells Postgres to spread the "writing" over 90% of the time available before the next checkpoint. It turns a "data dump" into a "slow leak," which prevents disk I/O spikes.



---

### 2. The "Size" Settings

Postgres will trigger a checkpoint either when the `timeout` hits **OR** when the WAL (logs) get too big. On a heavy write load, the WAL fills up fast.

* **`max_wal_size`**:
* *Default:* 1GB.
* *Tuned:* **16GB to 64GB** (depending on your disk space).
* *Why:* If this is too low, Postgres will trigger "emergency" checkpoints every minute because the logs are full. You want `max_wal_size` big enough that your `checkpoint_timeout` is usually the thing that triggers the save, not the log size.



---

### 3. Monitoring for "Panic" Checkpoints

If you aren't sure if your settings are working, check your PostgreSQL logs. If you see this message:

> `LOG: checkpoints are occurring too frequently (every 10 seconds)`

**That is a red alert.** It means your `max_wal_size` is way too small. Postgres is panicking and flushing data to disk constantly to make room for more logs, which kills performance.


---

### Important Side Effect: Recovery Time

**The Trade-off:** By increasing these values, you are telling Postgres, *"I'm okay if it takes 5–10 minutes to start back up after a crash in exchange for better performance while I'm running."* If your business requires the database to be back online in 30 seconds after a crash, you have to keep these settings tighter.

**Would you like me to show you the SQL command to check how often your checkpoints have been triggering lately?**