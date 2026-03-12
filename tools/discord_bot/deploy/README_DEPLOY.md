# DraconicBot -- Oracle Cloud Deployment Guide

This guide deploys DraconicBot to an Oracle Cloud Always Free ARM VM.

Total cost: $0/month (Always Free tier).

## Prerequisites

- Oracle Cloud account (free tier is sufficient)
- Discord bot token (from the [Developer Portal](https://discord.com/developers/applications))
- SSH key pair (or generate one during VM creation)

---

## Step 1: Create the VM

1. Log in to [Oracle Cloud Console](https://cloud.oracle.com)
2. Navigate to **Compute > Instances > Create Instance**
3. Configure:

| Setting | Value |
|---------|-------|
| Name | `draconic-bot` |
| Image | **Oracle Linux 9** (or Ubuntu 22.04/24.04 Minimal) |
| Shape | **VM.Standard.A1.Flex** (Ampere ARM) |
| OCPUs | **1** |
| Memory | **6 GB** |
| Boot volume | 47 GB (default, free) |
| SSH key | Upload your public key or let OCI generate one |

4. Under **Networking**, use the default VCN or create one. The bot only needs **outbound** internet access (no inbound ports required).

5. Click **Create** and wait for the instance to reach RUNNING state.

6. Note the **Public IP Address** from the instance details page.

### Firewall Note

DraconicBot connects *outbound* to Discord's gateway (wss://gateway.discord.gg). No inbound ports need to be opened. The default OCI security list allows all outbound traffic, so no firewall changes are needed.

---

## Step 2: SSH into the VM

```bash
# Oracle Linux default user is 'opc', Ubuntu is 'ubuntu'
ssh -i ~/.ssh/your_key opc@<PUBLIC_IP>
```

Verify connectivity:
```bash
curl -s https://discord.com/api/v10/gateway | python3 -m json.tool
# Should return: {"url": "wss://gateway.discord.gg"}
```

---

## Step 3: Transfer Bot Files

From your local machine (Windows), transfer the bot directory:

```bash
# Option A: scp (simple)
scp -i ~/.ssh/your_key -r tools/discord_bot/ opc@<PUBLIC_IP>:~/discord_bot/

# Option B: rsync (faster for updates, preserves permissions)
rsync -avz -e "ssh -i ~/.ssh/your_key" \
  --exclude='__pycache__/' \
  --exclude='logs/' \
  --exclude='.env' \
  tools/discord_bot/ opc@<PUBLIC_IP>:~/discord_bot/
```

If using Git instead:
```bash
# On the VM
git clone https://github.com/VoxCore84/RoleplayCore.git ~/VoxCore
# Bot is at ~/VoxCore/tools/discord_bot/
```

---

## Step 4: Configure Environment

SSH into the VM and set up the .env file:

```bash
cd ~/discord_bot/
cp deploy/.env.example .env
nano .env
```

At minimum, set:
- `DISCORD_TOKEN` -- your bot token (required)
- Channel IDs for the channels you want the bot to monitor

Save and exit (Ctrl+X, Y, Enter in nano).

---

## Step 5: Run the Deploy Script

```bash
cd ~/discord_bot/deploy/
chmod +x deploy.sh
sudo ./deploy.sh
```

The script will:
1. Install Python 3.12 and pip
2. Create a `draconic` system user
3. Copy bot files to `/opt/draconic-bot/`
4. Create a virtualenv and install dependencies
5. Install and start the systemd service

---

## Step 6: Verify

```bash
# Check service status
sudo systemctl status draconic

# Watch live logs
journalctl -u draconic -f

# You should see:
#   Bot ready: DraconicBot#1234 (ID: ...)
#   Connected to N guild(s)
#   Synced N slash commands
```

Test in Discord: type `/help` in any channel the bot can see.

---

## Updating the Bot

When you push code changes:

```bash
# From your local machine, sync the updated files
rsync -avz -e "ssh -i ~/.ssh/your_key" \
  --exclude='__pycache__/' \
  --exclude='logs/' \
  --exclude='.env' \
  --exclude='deploy/' \
  tools/discord_bot/ opc@<PUBLIC_IP>:~/discord_bot/

# SSH in and re-deploy
ssh -i ~/.ssh/your_key opc@<PUBLIC_IP>
cd ~/discord_bot/deploy/
sudo ./deploy.sh
```

Or for quick restarts after small changes:

```bash
# Copy changed files directly to the install dir
sudo rsync -av --exclude='__pycache__/' ~/discord_bot/ /opt/draconic-bot/
sudo chown -R draconic:draconic /opt/draconic-bot/
sudo systemctl restart draconic
```

---

## Monitoring and Maintenance

### View Logs

```bash
# Live tail
journalctl -u draconic -f

# Last 100 lines
journalctl -u draconic -n 100

# Since last boot
journalctl -u draconic -b

# Bot's own rotating log files
ls -la /opt/draconic-bot/logs/
cat /opt/draconic-bot/logs/draconic_bot.log
```

### Restart / Stop

```bash
sudo systemctl restart draconic    # Restart
sudo systemctl stop draconic       # Stop
sudo systemctl start draconic      # Start
sudo systemctl disable draconic    # Disable auto-start on boot
```

### Check Resource Usage

```bash
# Memory and CPU
systemctl status draconic
ps aux | grep discord_bot

# Disk usage
du -sh /opt/draconic-bot/
df -h /
```

---

## Docker Alternative

If you prefer Docker over systemd:

```bash
# Install Docker (Oracle Linux 9)
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker opc

# Install Docker Compose plugin
sudo dnf install -y docker-compose-plugin

# Deploy
cd ~/discord_bot/
cp deploy/.env.example .env
nano .env  # Set DISCORD_TOKEN

docker compose -f deploy/docker-compose.yml up -d

# View logs
docker compose -f deploy/docker-compose.yml logs -f
```

For Ubuntu:
```bash
# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

# Same compose commands as above
```

---

## Troubleshooting

### Bot won't start

```bash
# Check the logs first
journalctl -u draconic -e --no-pager

# Common causes:
# 1. DISCORD_TOKEN not set or invalid
# 2. Python dependencies missing (re-run deploy.sh)
# 3. Permission issues (check ownership of /opt/draconic-bot/)
```

### Bot starts but no slash commands

```bash
# Slash commands take up to 1 hour to propagate globally.
# For instant sync in a test guild, the bot syncs on startup automatically.
# Check logs for "Synced N slash commands" message.
```

### Bot disconnects frequently

```bash
# Check if the VM is running out of memory
free -h
journalctl -u draconic --since "1 hour ago" | grep -i "error\|disconnect\|resume"

# Oracle Always Free VMs occasionally get reclaimed if idle.
# The systemd service auto-restarts, but check uptime:
uptime
```

### Cannot reach Discord API

```bash
# Test outbound connectivity
curl -s https://discord.com/api/v10/gateway
# If this fails, check OCI security list / firewall rules for outbound HTTPS
```

### Update Python dependencies

```bash
sudo -u draconic /opt/draconic-bot/venv/bin/pip install --upgrade -r /opt/draconic-bot/requirements.txt
sudo systemctl restart draconic
```

---

## Security Notes

- The bot runs as an unprivileged `draconic` user (no sudo, no shell)
- `.env` is chmod 600 (readable only by owner)
- systemd sandboxing: `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`
- No inbound ports required -- the bot only makes outbound connections
- The Discord token is the only true secret -- rotate it if compromised at: https://discord.com/developers/applications
