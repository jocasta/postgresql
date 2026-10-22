# AWS Just Put DuckDB Inside PostgreSQL. Data Engineers Have Some Rethinking to Do.

!!! info "Source"
    **KanishkSingh** on Medium · 2 Oct 2026 · 5 min read ·
    [Original article](https://medium.com/@singhkanishk098/aws-just-put-duckdb-inside-postgresql-data-engineers-have-some-rethinking-to-do-96a0ef94c151)

If you’ve built more than a couple of data pipelines, you’ve built this one before. Your orders live in Postgres. Three years of history got too expensive to keep there, so it moved to S3 as Parquet or Iceberg. The business wants one dashboard that shows both. So you write an ETL job, schedule it, and keep your phone nearby for the 2 AM page when it breaks.

AWS just made that specific job unnecessary for a lot of teams, by putting a DuckDB-powered query engine directly inside Aurora PostgreSQL. Worth noting upfront: DuckDB’s creators, DuckLabs, joined AWS in 2025, which is exactly the kind of move that makes a feature like this possible AWS now owns the engine it’s embedding. Here’s the part that matters for your day job.

![Image on unsplash by Mehmet Ali Peker](images/aws-duckdb-inside-postgresql-1.png)
*Image on unsplash by Mehmet Ali Peker*

## The pipeline you’ve been maintaining

```text
Postgres (OLTP)                         S3 (OLAP)
   orders, last 90 days          3 years of history, Parquet/Iceberg
        │                                      │
        │          nightly ETL job             │
        └──────────────────►  copy  ◄──────────┘
                               │
                         single warehouse table
                               │
                           dashboard
```

Two separate systems, a scheduled copy job stitching them together, and a failure mode every time the schema drifts or the job overruns its window.

## What changes

You turn on an extension (AWS calls it `aurora_analytics`), point a foreign table at your S3 location, and query across both worlds with plain SQL no copy step in between.

```sql
-- one-time setup
CREATE EXTENSION aurora_analytics;

-- point at the Parquet files already sitting in S3
CREATE FOREIGN TABLE orders_history ()
SERVER s3_analytics
OPTIONS (files 's3://my-bucket/orders/*.parquet');

-- Aurora reads the Parquet metadata and infers the columns for you -
-- you don't hand-type a schema

SELECT o.customer_id, o.amount, o.created_at
FROM orders o -- live table in Postgres
UNION ALL
SELECT h.customer_id, h.amount, h.created_at
FROM orders_history h -- foreign table backed by S3
WHERE h.created_at > now() - interval '3 years';
```

```text
Postgres (OLTP)                         S3 (OLAP)
   orders, live                   history, Parquet/Iceberg/Glue Catalog
        │                                      │
        └──────────── one SQL query ───────────┘
                               │
                           dashboard
```

No copy step. No schedule. No 2 AM page for this part.

That’s the whole trick architecturally: Aurora pushes the analytical half of the query down to an embedded DuckDB engine, which is built for exactly this kind of scan-heavy, columnar work, while Postgres keeps doing what it’s good at for the live rows.

## What it can actually read

- Parquet files sitting in S3
- Iceberg tables, in S3 or in S3 Tables
- Iceberg tables registered in the AWS Glue Data Catalog

## What it can’t do, and what it’ll cost you

Four things worth knowing before you rip out your ETL job:

**It’s read-only.** It does not write back into Iceberg. If you want to persist results, you land them in a normal Aurora table with `CREATE TABLE AS SELECT`, `INSERT INTO ... SELECT`, or `MERGE`.

**Version floor.** You need Aurora PostgreSQL 17.11 or 18.6+. Older clusters don’t get this.

**No feature tax, but there’s a compute tax.** There’s no extra charge for the extension itself you pay for Aurora compute and the S3 requests you make. But heavy analytical queries still run on your database instance, so a dashboard that scans three years of history on every refresh will show up on your Aurora bill. Watch it.

**It’s still one query engine doing two jobs.** This removes a pipeline, not query planning. A badly written analytical query can still crowd out your OLTP workload if you’re not paying attention to how much it’s scanning.

A small Go health-check, the kind you’d actually drop into a cron job or a readiness probe, makes the cost side concrete: it separates a cheap OLTP-style query from an expensive cross-source scan and logs how long each one takes, so a slow analytical query shows up before it eats your transactional latency budget.

```go
package main

import (
	"context"
	"database/sql"
	"log"
	"time"
	_ "github.com/lib/pq"
)

// checkQuery times a single query and flags it if it crosses a threshold.
// Point this at your foreign-table queries after rollout - it's the
// cheapest way to catch a scan that's quietly getting expensive.
func checkQuery(ctx context.Context, db *sql.DB, label, query string, warnAfter time.Duration) {
	start := time.Now()
	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		log.Printf("[%s] query failed: %v", label, err)
		return
	}
	defer rows.Close()
	count := 0
	for rows.Next() {
		count++
	}
	elapsed := time.Since(start)
	status := "ok"
	if elapsed > warnAfter {
		status = "SLOW"
	}
	log.Printf("[%s] rows=%d elapsed=%s status=%s", label, count, elapsed, status)
}

func main() {
	db, err := sql.Open("postgres", "postgres://user:pass@aurora-host:5432/mydb?sslmode=require")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	// cheap: hits the live OLTP table, indexed lookup
	checkQuery(ctx, db, "live_orders",
		`SELECT id FROM orders WHERE customer_id = 42 LIMIT 10`,
		200*time.Millisecond)
	// potentially expensive: scans the S3-backed foreign table
	checkQuery(ctx, db, "history_scan",
		`SELECT count(*) FROM orders_history WHERE created_at > now() - interval '1 year'`,
		2*time.Second)
}
```

Nothing clever here on purpose , it’s the kind of script a data engineer actually writes the week after turning a feature like this on, to find out which dashboards got quietly expensive.

## The concepts underneath, which outlast the feature

The AWS feature is new. What it’s built on isn’t, and this is the part worth actually learning rather than skimming past:

- **OLTP vs. OLAP** Postgres is tuned for lots of small reads and writes on individual rows. DuckDB is tuned for scanning millions of rows to answer one aggregate question. This feature works because it routes each query to the engine suited for it.
- **Row storage vs. column storage** Postgres stores a row together on disk, good for “give me this one order.” Parquet stores a column together, good for “sum this one field across three years.” That’s why the S3 side of this is Parquet/Iceberg and not more Postgres tables.
- **Predicate pushdown and column pruning** a well-written query only pulls the columns and row ranges it actually needs from S3, instead of dragging the whole file in before filtering. This is where most of your cost control will come from in practice.
- **Open table formats like Iceberg** Iceberg adds schema evolution, snapshots, and time travel on top of plain Parquet, which is why it keeps showing up as the format of choice for lakehouse features like this one across AWS, Snowflake, and Databricks.

If those four ideas are already solid for you, a launch like this takes about two minutes to actually understand you’re just watching a new UI get put on the same physics. If they’re not solid yet, this is a good excuse to learn them, because they’ll outlive this specific AWS feature by a long way.

Tools keep merging. The concepts underneath them don’t change nearly as often.
