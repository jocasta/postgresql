
A good internal mantra:

“First: make it safe.
Second: make it predictable.
Third: make it scalable.”


-------------------------------------------------------------------------------------------------

* Data ingestion - how is data written to the DB

* Vacuuming

* transaction wraparound


-------------------------------------------------------------------------------------------------


* WRITE DOWN THE DATA STRUCTURE - SO IF YOU GET THE JOB YOU CAN PREPARE

* Data structure of the HOT table - JSONB?  

* Ingestion of data - how this happens

* How Many Warehouses? 

* Are all queries strictly related to a specific warehouse? 

* UUID (pros / cons) - they are using UUID-v4

PostgreSQL UUIDs give globally unique IDs without coordination; v4 is random but hurts index locality, while newer time-ordered UUIDs like v7 scale much better for large tables.

* Migrations - Schema migrations

> migrating a column based that is already included in a unique index

* Transaction Wraparound  /  Vacuuuming 

* pg_repack (this works well on partitioning)

-----------------------------------------------------------------------------------------------

* Go over how the data is backed up

* Go over Restores

* Go Over Disaster Recovery plans

* GitHub / GitLab  ( GitLab Runners / GitHub Actions)

--------------------------------------------------------------------------------------------

WHAT WOULD YOU DO ON DAY ONE:

(1) - Baseline everything: 

               - table sizes

--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------


* What OS can I work on? Linux? you give me a laptop? 