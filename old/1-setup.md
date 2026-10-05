

<details>

<summary>Install in VS Code:</summary>

<br>

> Dev Containers extension
> Claude Code extension
> Python extension

</details>

<hr>

<details>

<summary> Create .devcontainers/devcontainer.json</summary>

<br>

```json
{
  "name": "trading-bot",
  "build": {
    "dockerfile": "Dockerfile"
  },
  "workspaceFolder": "/workspaces/betfair-bot",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/betfair-bot,type=bind",
  "remoteUser": "vscode",
  "mounts": [
    "source=${env:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly",
    "source=${env:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ],
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff",
        "ms-azuretools.vscode-docker"
      ]
    }
  },
  "postCreateCommand": "pip install -e '.[dev]'"
}
```

</details>

<hr>

<details>

<summary> Add .devcontainer/Dockerfile</summary>
 
 <br>

```sh
FROM mcr.microsoft.com/devcontainers/python:3.12

RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    less \
    vim \
    postgresql-client \
    build-essential \
    systemd \
    iproute2 \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

USER vscode

# Claude Code native installer
RUN curl -fsSL https://claude.ai/install.sh | bash || true

ENV PATH="/home/vscode/.local/bin:${PATH}"
```

</details>

<hr>

<details>

<br>

<summary>Add pyproject.toml</summary>

```toml
[project]
name = "betfair-bot"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "aiohttp",
  "websockets",
  "pydantic",
  "pydantic-settings",
  "asyncpg",
  "psycopg[binary]",
  "python-dotenv",
  "typer",
  "rich",
  "orjson",
]

[project.optional-dependencies]
dev = [
  "pytest",
  "pytest-asyncio",
  "ruff",
  "mypy",
  "types-requests",
]

[tool.ruff]
line-length = 100

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

</details>


<hr>

<details>

<summary>Open in Container</summary>

<br> 

<b>ctrl+shift+p</b>

> → Dev Containers: Reopen in Container

</details>


<hr>

<details>

<summary>Then inside the VS Code Terminal</summary>

<br> 

> $ claude

First launch should authenticate in the browser. If it does not open automatically, Claude’s docs say you can copy the login URL and paste it into your browser

## Once Authenticated from the repo root:

> $ /init

Then create a CLAUDE.md like this:

```markdown
# Betfair Bot Project

Python 3.12 application for Betfair Exchange streaming.

## Architecture

Use a modular structure:

- stream: Betfair streaming client, parser, subscription manager
- markets: market registry and market state
- strategy: Over 3.5 goals strategy logic
- execution: order manager, green-up logic, risk controls
- persistence: PostgreSQL storage
- services: long-running service entrypoints
- cli: Typer-based commands
- systemd: production unit files

## Rules

- Prefer async Python.
- Keep business logic separate from Betfair transport code.
- Do not hardcode secrets.
- Use environment variables and .env files for local development.
- Add tests for parser, strategy, and risk logic.
- Before large edits, explain the plan first.
- After changes, run: ruff check ., mypy src, pytest.
```

</details>