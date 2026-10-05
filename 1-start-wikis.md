## Starting the Wikis

This project uses [Zensical](https://zensical.org/), a static site generator from the creators of Material for MkDocs.

Each wiki lives under `wikis/<name>/` and has its own `zensical.toml` config.

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

<summary>Setting up Zensical (if it's not installed)</summary>

<br>

First check whether it's already available:

```sh
zensical --version
```

If you get `command not found`, install it using one of the options below.

**Inside the devcontainer**

The devcontainer installs Zensical automatically on creation (`postCreateCommand` runs `pip install -r requirements.txt`). If it's missing, rerun that by hand:

```sh
pip install -r requirements.txt
```

**On the host machine (e.g. Fedora)**

Don't install it with your distro package manager, and don't use `sudo pip`. Pick one of these:

- **pipx**: installs Zensical in its own environment and puts it on your `PATH`:

    ```sh
    sudo dnf install pipx    # if pipx isn't already installed
    pipx ensurepath          # then open a new shell
    pipx install zensical
    ```

- **Virtual environment** (keeps it tied to this repo):

    ```sh
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    ```

    Run `source .venv/bin/activate` again in each new shell before running `zensical`.

If `pip install --user` puts the binary in `~/.local/bin`, make sure that directory is on your `PATH`.

Confirm it's working:

```sh
zensical --version
```

</details>

<hr>

<details>

<summary>Serve a wiki locally (live reload)</summary>

<br>

From the repo root, pass the wiki's config file with `-f`:

```sh
zensical serve -f wikis/postgres/zensical.toml
```

Zensical starts a dev server on `http://localhost:8000/`. To open the page in your browser automatically, add `-o`:

```sh
zensical serve -f wikis/postgres/zensical.toml -o
```

The page reloads automatically when you save a file.

</details>

<hr>

<details>

<summary>Build a wiki to static HTML</summary>

<br>

```sh
zensical build -f wikis/postgres/zensical.toml
```

The output goes to `wikis/postgres/site/`. Open `site/index.html` directly or serve it with any static file server.

</details>

<hr>

<details>

<summary>Serve on a different port</summary>

<br>

This is useful when running more than one wiki at the same time:

```sh
zensical serve -f wikis/postgres/zensical.toml -a localhost:8001
```

</details>

<hr>

<details>

<summary>Adding a new wiki</summary>

<br>

1. Create the directory, then scaffold a template project:

```sh
mkdir -p wikis/<name>
zensical new wikis/<name>
```

This creates a `zensical.toml` and a `docs/` folder with a starter `index.md`.

2. Edit `wikis/<name>/zensical.toml`. At minimum, set `site_name` and the `nav` under `[project]`:

```toml
[project]
site_name = "My Wiki"

nav = [
  { "Home" = "index.md" },
]
```

The existing `wikis/postgres/zensical.toml` shows a working example, including the theme palette and the light/dark toggle.

3. Serve it:

```sh
zensical serve -f wikis/<name>/zensical.toml
```

4. Add the new wiki to the **Current wikis** table above.

</details>

<hr>

<details>

<summary>Updating Zensical</summary>

<br>

Zensical is listed in `requirements.txt`. To upgrade it:

```sh
pip install --upgrade -r requirements.txt    # devcontainer / venv
pipx upgrade zensical                        # if installed with pipx
```

To check which version is installed:

```sh
zensical --version
```

</details>
