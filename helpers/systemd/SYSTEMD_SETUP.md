# Systemd Service Setup

Manual systemd service installation guide.

## Quick Install

```bash
# Copy files to server
scp helpers/terraria-start ts:/opt/terraria-server/
scp helpers/systemd/*.{service,path} ts:/tmp/

# On server
sudo mv /tmp/terraria*.{service,path} /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/terraria*
sudo chmod +x /opt/terraria-server/terraria-start
sudo systemctl daemon-reload
sudo systemctl enable --now terraria.service terraria-restart.path
```

## Service Management

| Command | Description |
|---------|-------------|
| `sudo systemctl start terraria` | Start server |
| `sudo systemctl stop terraria` | Stop server |
| `sudo systemctl restart terraria` | Restart server |
| `sudo systemctl status terraria` | Check status |
| `sudo journalctl -u terraria -f` | Live logs |
| `sudo journalctl -u terraria -n 50` | Last 50 lines |

## Configuration

Create `/opt/terraria-server/config/serverconfig.txt`:

```
world=/opt/terraria-server/worlds/World.wld
autocreate=0
worldname=World
difficulty=0
maxplayers=8
port=7777
password=
```

## Files

- `terraria.service` - Main service
- `terraria-restart.service` - Auto-restart helper
- `terraria-restart.path` - Watches for updates
- `terraria-start` - Launch wrapper script

## How Auto-Restart Works

1. `terraria-restart.path` monitors `/opt/terraria-server/current` symlink
2. When `server-update` changes the symlink, path unit triggers
3. `terraria-restart.service` runs and restarts the main service
4. Server automatically uses the new version

## Manual Installation Steps

### 1. Copy Files

```bash
# From local machine
scp helpers/terraria-start ts:/tmp/
scp helpers/systemd/terraria.service ts:/tmp/
scp helpers/systemd/terraria-restart.service ts:/tmp/
scp helpers/systemd/terraria-restart.path ts:/tmp/
```

### 2. Install on Server

```bash
# On server
sudo mv /tmp/terraria-start /opt/terraria-server/
sudo chmod +x /opt/terraria-server/terraria-start
sudo sed -i 's/\r$//' /opt/terraria-server/terraria-start  # Fix line endings

sudo mv /tmp/terraria.service /etc/systemd/system/
sudo mv /tmp/terraria-restart.service /etc/systemd/system/
sudo mv /tmp/terraria-restart.path /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/terraria*
```

### 3. Enable and Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable terraria.service terraria-restart.path
sudo systemctl start terraria.service terraria-restart.path
```

## Troubleshooting

**Service fails to start:**
```bash
sudo journalctl -u terraria -n 100
sudo systemctl status terraria
ls -la /opt/terraria-server/current
```

**Auto-restart not working:**
```bash
sudo systemctl status terraria-restart.path
sudo journalctl -u terraria-restart -n 20
ls -la /opt/terraria-server/current
```

**Permission issues:**
```bash
ls -la /opt/terraria-server/
sudo chown -R atlas:atlas /opt/terraria-server/
sudo chmod +x /opt/terraria-server/terraria-start
```

## Uninstall

```bash
sudo systemctl stop terraria.service terraria-restart.path
sudo systemctl disable terraria.service terraria-restart.path
sudo rm /etc/systemd/system/terraria*.{service,path}
sudo systemctl daemon-reload
```
