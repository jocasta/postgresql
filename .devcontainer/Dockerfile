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