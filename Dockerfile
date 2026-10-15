FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install required certificates, networking, and common dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    bash \
    sudo \
    tar \
    gzip \
    iproute2 \
    procps \
    docker.io \
    python3 \
    python3-pip \
    build-essential \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Pre-create directory structures
RUN mkdir -p /workspaces /host /root/.gemini /home/codespace/.gemini

WORKDIR /workspaces
CMD ["/usr/local/bin/agy", "--remote-control", "--dangerously-skip-permissions"]
