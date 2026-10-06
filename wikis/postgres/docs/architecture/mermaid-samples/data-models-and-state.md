# Data Models & State

## ER diagram

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ ORDER_ITEM : contains
    PRODUCT ||--o{ ORDER_ITEM : "ordered as"
    CUSTOMER {
        bigint id PK
        text email UK
        timestamptz created_at
    }
    ORDER {
        bigint id PK
        bigint customer_id FK
        text status
        timestamptz created_at
    }
    ORDER_ITEM {
        bigint order_id PK, FK
        bigint product_id PK, FK
        int quantity
        numeric unit_price
    }
    PRODUCT {
        bigint id PK
        text sku UK
        jsonb attrs
    }
```

## Class diagram — catalog relationships

```mermaid
classDiagram
    class pg_database {
        oid
        datname
        datfrozenxid
    }
    class pg_namespace {
        oid
        nspname
    }
    class pg_class {
        oid
        relname
        relkind
        relnamespace
        reltuples
    }
    class pg_index {
        indexrelid
        indrelid
        indisunique
    }
    class pg_attribute {
        attrelid
        attname
        atttypid
    }
    pg_namespace "1" --> "*" pg_class : contains
    pg_class "1" --> "*" pg_attribute : has columns
    pg_class "1" --> "*" pg_index : indexed by
```

## State diagram — backend state (pg_stat_activity.state)

```mermaid
stateDiagram-v2
    [*] --> idle : connection established
    idle --> active : query received
    active --> idle : query done (autocommit)
    active --> idle_in_transaction : statement done inside BEGIN
    idle_in_transaction --> active : next statement
    idle_in_transaction --> idle : COMMIT / ROLLBACK
    active --> idle_in_transaction_aborted : error inside transaction
    idle_in_transaction_aborted --> idle : ROLLBACK
    idle --> [*] : disconnect

    idle_in_transaction : idle_in_transaction
    idle_in_transaction : ⚠ holds locks, blocks vacuum
```

!!! warning "idle in transaction"
    Sessions sitting in `idle_in_transaction` hold their locks and prevent vacuum from removing dead tuples.
    Cap them with `idle_in_transaction_session_timeout`.

!!! note "Mermaid notes in state diagrams"
    Zensical's theme styles notes in sequence diagrams, but not `note … end note` blocks in **state diagrams**:
    they keep Mermaid's default black text and can overflow their box. Put the text in a state description
    (`state_id : text`) or an admonition instead.

## State diagram — tuple lifecycle under MVCC

```mermaid
stateDiagram-v2
    direction LR
    [*] --> Live : INSERT (xmin set)
    Live --> Dead : UPDATE / DELETE commits (xmax set)
    Live --> Frozen : VACUUM FREEZE
    Dead --> Reclaimable : no snapshot can see it
    Reclaimable --> [*] : VACUUM removes it
    state Live {
        [*] --> NotAllVisible
        NotAllVisible --> AllVisible : VACUUM sets VM bit
    }
```
