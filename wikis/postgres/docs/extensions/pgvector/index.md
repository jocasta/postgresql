# pgvector

Vector similarity search for PostgreSQL — store embeddings and query nearest neighbours.

- **Type:** third-party (available on RDS, Aurora, Cloud SQL, Azure, etc.)
- **Preload required:** No
- **Repo:** <https://github.com/pgvector/pgvector>

---

## Install

```sql
CREATE EXTENSION IF NOT EXISTS vector;   -- note: extension name is "vector"
SELECT extversion FROM pg_extension WHERE extname = 'vector';
```

---

## Types and operators

| Type | Notes |
|---|---|
| `vector(n)` | 32-bit floats, up to 2,000 dims indexable |
| `halfvec(n)` | 16-bit floats, up to 4,000 dims indexable (0.7+) |
| `sparsevec(n)` | Sparse vectors (0.7+) |
| `bit(n)` | Binary vectors — Hamming / Jaccard (0.7+) |

| Operator | Distance | Index opclass |
|---|---|---|
| `<->` | L2 (Euclidean) | `vector_l2_ops` |
| `<#>` | Negative inner product | `vector_ip_ops` |
| `<=>` | Cosine | `vector_cosine_ops` |
| `<+>` | L1 (Manhattan) | `vector_l1_ops` |

---

## Example

```sql
CREATE TABLE documents (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content   text,
    embedding vector(1536)
);

-- HNSW: better recall/speed trade-off, slower build, more memory
CREATE INDEX documents_embedding_hnsw
    ON documents USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Query: 5 nearest by cosine distance
SELECT id, content, embedding <=> $1 AS distance
FROM documents
ORDER BY embedding <=> $1
LIMIT 5;
```

### HNSW vs IVFFlat

| | HNSW | IVFFlat |
|---|---|---|
| Build | Slower, more memory | Faster, needs data present first (`lists`) |
| Query recall | Higher | Lower for same speed |
| Tuning knob | `SET hnsw.ef_search = 100;` (default 40) | `SET ivfflat.probes = 10;` (default 1) |
| Can build on empty table | Yes | Not usefully — build after loading |

```sql
-- IVFFlat: rows/1000 lists up to 1M rows, sqrt(rows) above that
CREATE INDEX ON documents USING ivfflat (embedding vector_l2_ops) WITH (lists = 1000);
```

---

## Tuning & gotchas

- Index builds: raise `maintenance_work_mem` (graph should fit in memory) and `max_parallel_maintenance_workers`.
- Filtering + ANN: a `WHERE` clause is applied *after* the index scan, so you can get fewer than `LIMIT` rows.
  In 0.8+ enable `SET hnsw.iterative_scan = relaxed_order;` (or `ivfflat.iterative_scan`), or use partial indexes / partitioning per filter value.
- The operator in `ORDER BY` must match the index opclass or the index won't be used.
- Normalised embeddings (e.g. OpenAI) → inner product (`<#>`) gives the same ranking as cosine and is slightly faster.
