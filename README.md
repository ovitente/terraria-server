# Terraria Server on Hetzner Cloud

Simple automated Terraria server deployment on Hetzner Cloud.

## Features

- Automated server updates
- Systemd service with auto-restart
- Makefile for easy management
- Automatic world backups
- Quick snapshot/restore

## Prerequisites

- Hetzner Cloud account & API token
- `make`, `hcloud` CLI installed locally

## Quick Start

1. **Install hcloud CLI**
   ```bash
   # Arch Linux
   sudo pacman -S hcloud

   # Other distributions
   curl -L https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz | tar xz
   sudo mv hcloud /usr/local/bin/
   ```

2. **Configure hcloud**
   ```bash
   hcloud context create terraria
   # Paste your Hetzner API token
   ```

3. **Prepare cloud-init.yaml**

   Edit `cloud-init.yaml` and replace SSH keys with your own:
   ```bash
   cat ~/.ssh/id_ed25519.pub  # or id_rsa.pub
   ```

4. **Create firewall**
   ```bash
   make firewall-create
   ```

5. **Deploy server**
   ```bash
   make create-initial
   # Wait ~30 seconds for setup to complete
   ```

6. **Create snapshot for quick restore**
   ```bash
   make snapshot
   ```

## World Files

**IMPORTANT:** Place your world file in the `worlds/` directory. Only one world file should be present.

The world file must be named `Террария.wld` (or update the scripts to match your world name).

Example:
```bash
# Place your world file
cp /path/to/your/world.wld worlds/Террария.wld

# Deploy to server
make deploy-world
```

## Commands

| Command | Description |
|---------|-------------|
| `make up` | Create server from snapshot (fast) |
| `make create-initial` | Create NEW server with cloud-init (first setup) |
| `make delete` | Delete server (auto backup world) |
| `make backup-world` | Backup world file with timestamp |
| `make deploy-world` | Upload world from ./worlds/ and restart |
| `make snapshot` | Create server snapshot (with world backup) |
| `make status` | Show Hetzner server status |
| `make server-status` | Show Terraria service status |
| `make logs` | Show last 50 log lines |
| `make logs-live` | Show logs in real-time (Ctrl+C to exit) |
| `make restart` | Restart Terraria server |
| `make ip` | Show server IP address |
| `make ssh` | Connect to server |
| `make firewall-create` | Create firewall rules |
| `make firewall-delete` | Delete firewall |

## Manual Setup

For detailed manual setup instructions, see [Systemd Setup Guide](helpers/systemd/SYSTEMD_SETUP.md).

## File Structure on Server

```
/opt/terraria-server/
├── current → releases/terraria-server-XXXX
├── releases/
│   └── terraria-server-1454/
│       └── 1454/Linux/
├── config/
│   └── serverconfig.txt
├── worlds/
│   └── World.wld
├── state/
│   └── latest_zip.txt
├── server-update
└── terraria-start

/etc/systemd/system/
├── terraria.service
├── terraria-restart.service
└── terraria-restart.path
```

## Configuration

Edit `serverconfig.example.txt` and adjust:

- `worldname` - World name
- `password` - Server password (empty = no password)
- `maxplayers` - Max players
- `difficulty` - 0=Classic, 1=Expert, 2=Master
- `autocreate` - 0=disabled, 1=Small, 2=Medium, 3=Large

## Troubleshooting

**Server won't start:**
```bash
sudo journalctl -u terraria -n 100
ls -la /opt/terraria-server/current
```

**Can't connect:**
```bash
sudo systemctl status terraria
sudo ss -tulpn | grep 7777
```

**Auto-restart not working:**
```bash
sudo systemctl status terraria-restart.path
ls -la /opt/terraria-server/current
```

## SSH Alias (Optional)

Add to `~/.ssh/config`:

```
Host ts
    HostName <SERVER_IP>
    User atlas
    Port 22
    IdentityFile ~/.ssh/personal
```

Now connect with: `ssh ts`

## Updating Server

Updates happen automatically via `terraria-restart.path`. To manually update:

```bash
ssh ts
sudo /opt/terraria-server/server-update
# Server will auto-restart after update
```

## Advanced Commands

```bash
# Check server version
cat /opt/terraria-server/state/latest_zip.txt

# List all installed versions
ls -la /opt/terraria-server/releases/

# Switch to different version manually
sudo ln -sfn /opt/terraria-server/releases/terraria-server-XXXX /opt/terraria-server/current
sudo systemctl restart terraria

# Clean old versions (keep only current)
cd /opt/terraria-server/releases
CURRENT=$(basename $(readlink -f ../current))
ls | grep -v "$CURRENT" | xargs sudo rm -rf
```

## License

MIT
