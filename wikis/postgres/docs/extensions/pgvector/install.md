# pgvector: Install

```sql
CREATE EXTENSION IF NOT EXISTS vector;   -- note: extension name is "vector"
SELECT extversion FROM pg_extension WHERE extname = 'vector';
```
