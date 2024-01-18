
# Introduction
In this blog, we’ll go over PostgreSQL’s implementation and handling of JSON objects. Having some experience with Linux, Postgres, and JSON is necessary as we’ll not only be going over these new features but also how to implement them. This blog was written using PostgreSQL 16 (Development Version) running on Ubuntu 23.04. First, I’ll go over some background on JSON as a short refresher, then move on to how we use JSON in Postgres, followed by what helpful functions we can use to interact with JSON objects.

## Background
The JavaScript Object Notation (JSON) is an open standard file format for storing information in key, value pairs. It boasts a lightweight and language-independent format that is both human-legible and easy for machines to generate and parse. Its main advantage and why it has become so ubiquitous for data storage is its seamless interoperability between applications. This lends itself well to web applications as often we need two programs to communicate and each might be using a different language for its implementation. As long as each program has a way to parse JSON files, they should be able to communicate effectively regardless of what software or hardware the other is using. Now that we see how great JSON is for data storage, let’s look at how we can have it as part of our Postgres database.

## Using JSON
PostgreSQL has two datatypes for storing JSON data in a table, `json` and `jsonb`. The `json` type stores JSON data as a string, so when it is read back, the receiving application will need to convert the text back into a JSON object. The `jsonb` type, on the other hand, stores JSON objects directly as their binary representation. When we store a JSON object as `jsonb`, PostgreSQL maps the JSON types to its own datatypes. These follow from the PostgreSQL documentation:

| JSON primitive type | PostgreSQL type | Notes |
|----------------------|-----------------|-------|
| string | text | `\u0000` is disallowed, as are Unicode escapes representing characters not available in the database encoding |
| number | numeric | NaN and infinity values are disallowed |
| boolean | boolean | Only lowercase true and false spellings are accepted |
| null | (none) | SQL NULL is a different concept |

Both types accept nearly identical inputs; however, most applications will benefit more from using `jsonb` due to its efficiency. As such, our examples will primarily focus on using `jsonb`.

To start using JSON in Postgres, we first have to create a table with a column whose type is JSON.

```sql
CREATE TABLE t1 (id int, data jsonb);
```

Now we can insert some data

```sql
INSERT INTO t1 VALUES (1, '{"a":1, "b":"hello", "c":{"d":"world","e":2},"arr":[1,2,3]}');
```

Let’s see how that data is represented

```sql
SELECT * FROM t1;
```

```sql
 id |                     data                      
----+-----------------------------------------------
  1 | {"a":1, "b":"hello", "c":{"d":"world","e":2},"arr":[1,2,3]}
```

PostgreSQL doesn’t just store JSON objects; it has its own functions it can use to interact with the key, value pairs as parameters in queries. Let’s take a look at how that might be done.

## JSON Functions
### Operators
PostgreSQL implements operators for accessing elements from the JSON object. These operators are summarized in the PostgreSQL documentation:

| Operator | Right Operand Type | Description |
|----------|---------------------|-------------|
| ->       | int                 | Get JSON array element |
| ->       | text                | Get JSON object field |
| ->>      | int                 | Get JSON array element as text |
| ->>      | text                | Get JSON object field as text |
| #>       | array of text       | Get JSON object at specified path |
| #>>      | array of text       | Get JSON object at specified path as text |

Using these operators, we can access elements from the JSON object we inserted earlier. These operators return values would look like:

```sql
SELECT data->'a' AS result FROM t1;
```

```sql
 result 
--------
 1
```

```sql
SELECT data->'arr'->2 AS result FROM t1;
```

```sql
 result 
--------
 3
```

Now that we can access the values, we can use them for querying rows in our table.

```sql
INSERT INTO t1 VALUES (1,'{"num":12,"arr":[1,2,3]}'),(2,'{"num":14,"arr":[4,5,6]}'),(3,'{"num":16,"arr":[7,8,9]}');
```

```sql
SELECT data FROM t1 WHERE (data->'arr'->1)::integer >= 5;
```

```sql
          result          
--------------------------
 {"num":14,"arr":[4,5,6]}
 {"num":16,"arr":[7,8,9]}
```

As we can see, only rows whose 2nd element in the “arr” key was greater than or equal to 5 were selected.

### Subscripting
These JSON objects also support subscripting in Postgres like they do in many programming languages. We can convert the above operators into subscripts like so:

```sql
SELECT data FROM t1 WHERE (data['arr'][1])::integer >= 5;
```

```sql
             data              
-------------------------------
 {"arr": [4, 5, 6], "num": 14}
 {"arr": [7, 8, 9], "num": 16}
```

Like before, we can also use subscripting in the SELECT statement:

```sql
SELECT data['num'] FROM t1 WHERE (data['arr'][1])::integer >= 5;
```

```sql
 data 
------
 14
 16
```

This syntax might be more familiar to those who have experience with JSON. Feel free to use either as they function very similarly, accepting both text input for keys and integer indexes for arrays.

### Functions
PostgreSQL also implements more powerful functions for conversions and retrieving information like size, keys, and iterators for the JSON objects. Of course, like before, all of these functions can be used inside of queries, making JSON objects even more powerful inside a database. We’ll use the following table schema and data for our JSON function examples:

```sql
CREATE TABLE myjson (id int, data jsonb);
INSERT INTO myjson values(1,'{"mynum":1,"mytext":"hello","myarr":[1,2,3,4,5]}');
```

Many more functions can be found in table 9.41 of the PostgreSQL documentation. We’ll go over a brief subset of some of the more common functions here.

#### array_to_json
Converts any SQL value to a JSON Binary type

```sql
SELECT to_jsonb (data['myarr']) from myjson;
```

```sql
    to_jsonb     
-----------------
 [1, 2, 3, 4, 5]
```

#### jsonb_array_length
Returns the number of elements in a JSON Binary array.

```sql


SELECT jsonb_array_length (data['myarr']) from myjson;
```

```sql
 jsonb_array_length 
--------------------
                  5
```

#### jsonb_each
Converts top-level JSON object into a key, value pair.

```sql
SELECT jsonb_each (data) from myjson;
```

```sql
        jsonb_each         
---------------------------
 (myarr,"[1, 2, 3, 4, 5]")
 (mynum,1)
 (mytext,"""hello""")
```

#### jsonb_object_keys
Returns the keys of the JSON Binary object

```sql
SELECT jsonb_object_keys (data) from myjson;
```

```sql
 jsonb_object_keys 
-------------------
 myarr
 mynum
 mytext
```

## Conclusion
In this blog, we took a look at the PostgreSQL JSON datatype and how it can be used to store, access, and manage JSON objects. First, we looked at a brief background on the JSON format and its usefulness on the web. Then we looked at how we can set up a table to use a JSON datatype followed by the different methods we can access them with. Finally, we looked at a small subset of the functions our JSON objects will have access to and how these can be useful when implemented in queries. The JSON datatype is an incredibly flexible and interoperable object understood by a vast amount of web API interfaces. If your database interfaces with any sort of web application, consider how JSON might be used to streamline data passing between your applications.