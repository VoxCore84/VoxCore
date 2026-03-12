# DraconicBot — Production Dockerfile
# Targets: Oracle Cloud Always Free (ARM64 Ampere A1) or any x86_64 host
# Base: python:3.12-slim (Debian Bookworm, ~150MB)

FROM python:3.12-slim AS base

# Prevent Python from writing .pyc files and enable unbuffered stdout/stderr
# so logs appear immediately in `docker logs` and journald
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install only the OS packages needed at runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends tini procps && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for the bot process
RUN groupadd --gid 1000 draconic && \
    useradd --uid 1000 --gid draconic --shell /bin/bash --create-home draconic

# The bot is a Python package (discord_bot/) that uses `python -m discord_bot`.
# We place the package inside /opt/bot/ so the module path resolves correctly.
WORKDIR /opt/bot

# Install Python dependencies first (layer cache optimization —
# requirements change less often than source code)
COPY requirements.txt discord_bot/requirements.txt
RUN pip install --no-cache-dir -r discord_bot/requirements.txt

# Copy the full bot source tree into the discord_bot package directory
COPY . discord_bot/

# Create the logs and data directories (writable by the bot user)
RUN mkdir -p /opt/bot/discord_bot/logs /opt/bot/discord_bot/data && \
    chown -R draconic:draconic /opt/bot

# Drop to non-root
USER draconic

# Health check: verify the Python process is alive.
# discord.py bots don't serve HTTP, so we check the process directly.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD pgrep -f "discord_bot" > /dev/null || exit 1

# Use tini as PID 1 so signals (SIGTERM from Docker) are forwarded correctly
ENTRYPOINT ["tini", "--"]
CMD ["python", "-m", "discord_bot"]
