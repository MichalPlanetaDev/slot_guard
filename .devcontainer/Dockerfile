FROM mcr.microsoft.com/devcontainers/base:bookworm

USER root

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      libpq-dev \
      libvips \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

USER vscode
