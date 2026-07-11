## Starting the Wikis

This project uses [MkDocs](https://www.mkdocs.org/) with the [Material theme](https://squidfunk.github.io/mkdocs-material/).

Each wiki lives under `wikis/<name>/` and has its own `mkdocs.yml` config.

---

<details>

<summary>Current wikis</summary>

<br>

| Wiki | Path |
|------|------|
| PostgreSQL | `wikis/postgres/` |

</details>

<hr>

<details>

<summary>Serve a wiki locally (live reload)</summary>

<br>

From the repo root, pass the wiki's config file with `-f`:

```sh
mkdocs serve -f wikis/postgres/mkdocs.yml
```

MkDocs will start a dev server and print the local URL:

```
INFO    -  Documentation built in 0.XX seconds
INFO    -  [HH:MM:SS] Serving on http://127.0.0.1:8000/
```

Open that URL in your browser. The page reloads automatically when you save a file.

</details>

<hr>

<details>

<summary>Build a wiki to static HTML</summary>

<br>

```sh
mkdocs build -f wikis/postgres/mkdocs.yml
```

Output lands in `wikis/postgres/site/`. Open `site/index.html` directly or serve it with any static file server.

</details>

<hr>

<details>

<summary>Serve on a different port</summary>

<br>

Useful when running multiple wikis at the same time:

```sh
mkdocs serve -f wikis/postgres/mkdocs.yml --dev-addr 127.0.0.1:8001
```

</details>

<hr>

<details>

<summary>Adding a new wiki</summary>

<br>

1. Create the directory structure:

```sh
mkdir -p wikis/<name>/docs
```

2. Add a `mkdocs.yml` (copy and adapt from an existing one):

```yaml
site_name: My Wiki

theme:
  name: material
  palette:
    - scheme: slate
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
    - scheme: default
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode

nav:
  - Home: index.md
```

3. Add a `docs/index.md` as the home page.

4. Serve it:

```sh
mkdocs serve -f wikis/<name>/mkdocs.yml
```

</details>

<hr>

<details>

<summary>Installing / updating dependencies</summary>

<br>

MkDocs and the Material theme are already installed in this devcontainer via `requirements.txt`.

Versions are pinned to avoid breaking changes from MkDocs 2.x and Material 10.x:

```
mkdocs<2
mkdocs-material<10
```

To reinstall manually:

```sh
pip install -r requirements.txt
```

To check what's installed:

```sh
pip show mkdocs mkdocs-material
```

</details>
