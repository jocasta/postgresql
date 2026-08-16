## Quick decision guide

| Query type             | Index      |
| ---------------------- | ---------- |
| `=` / `<` / `>`        | B-tree     |
| JSONB / arrays         | GIN        |
| Time-series huge table | BRIN       |
| Geo / distance         | GiST       |
| IP / hierarchical      | SP-GiST    |
| Full-text              | GIN / RUM  |
| Sparse “active” rows   | Partial    |
| Case-insensitive       | Expression |

---

## Rule of thumb

* Start with **B-tree**
* Add **GIN** for JSON/text
* Add **BRIN** for massive time-ordered tables
* Reach for GiST/SP-GiST only when you *know* why