# json

---

## Spitting out data from JSONB

### Pulling out selected element in json array

```sql
SELECT
   balance->>'date' AS balance_date,
   (balance->>'amount')::numeric AS balance_amount,
   balance->>'tag' AS balance_tag
 FROM
   moneyhub.test_json,
   jsonb_array_elements(data->'data'->'result'->0->'balances') AS balance;

```

### Pulling out all elements in json array

```sql
SELECT
   result->>'uid' AS uid,
   COALESCE(result->>'bankName', result->>'provider') AS bank,
   result->>'accountName' AS account_name,
   result->>'type' AS "type",
   result->>'subType' AS subtype,
   balance->>'date' AS balance_date,
   (balance->>'amount')::numeric AS balance_amount,
   balance->>'tag' AS balance_tag
FROM
   moneyhub.test_json,
   jsonb_array_elements(data->'data'->'result') AS result,
   LATERAL jsonb_array_elements(result->'balances') AS balance;


```

<details>
  <summary>Click to expand/collapse</summary>

  This is the content of the collapsible section.

  You can add any Markdown content here.

</details>


| Column 1 | Column 2 |
|----------|----------|
| Data 1   | Data 2   |
| <details> <summary>Click to expand/collapse</summary> This is the content of the collapsible section.  You can add any Markdown content here.</details>  | Data 5   |



