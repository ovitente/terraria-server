# Hetzner Cloud Terraria Server Management
# Requirements: hcloud CLI installed (https://github.com/hetznercloud/cli)
# Before usage: hcloud context create terraria

SHELL := bash

# ==== CONFIGURATION ====
# Can be overridden via environment variables or make arguments
SERVER_NAME ?= terraria-server
SNAPSHOT_NAME ?= terraria-snapshot
FIREWALL_NAME ?= terraria-firewall
SERVER_TYPE ?= cpx22
LOCATION ?= fsn1
TERRARIA_PORT ?= 7777
SSH_PORT ?= 22
SSH_USER ?= atlas
BASE_IMAGE ?= ubuntu-24.04
BACKUP_DIR ?= ./backups
BACKUP_REMOTE_PATH ?= /home/atlas/.local/share/Terraria
INITIAL_DEPLOY_SCRIPT ?= ./helpers/initial-deploy

# ==== MAIN COMMANDS ====

.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make up              - Create server from snapshot (fast start)"
	@echo "  make create-initial  - Create NEW server with cloud-init (first setup)"
	@echo "  make delete          - Delete server (with automatic world backup)"
	@echo "  make backup          - Create backup of Terraria files to local computer"
	@echo "  make backup-world    - Create world backup with timestamp (Terraria-DDMMYYYYHHMM.wld)"
	@echo "  make deploy-world    - Upload world from ./worlds/ to server and restart"
	@echo "  make snapshot        - Create server snapshot (without deletion, with world backup)"
	@echo "  make status          - Show Hetzner server status"
	@echo "  make server-status   - Show Terraria service status"
	@echo "  make logs            - Show last 50 lines of Terraria logs"
	@echo "  make logs-live       - Show Terraria logs in real-time"
	@echo "  make restart         - Restart Terraria server"
	@echo "  make ip              - Show server IP address"
	@echo "  make ssh             - Connect to server"
	@echo "  make firewall-create - Create firewall rules"
	@echo "  make firewall-delete - Delete firewall"
	@echo ""
	@echo "Configuration:"
	@echo "  SERVER_NAME=$(SERVER_NAME)"
	@echo "  SNAPSHOT_NAME=$(SNAPSHOT_NAME)"
	@echo "  FIREWALL_NAME=$(FIREWALL_NAME)"
	@echo "  SERVER_TYPE=$(SERVER_TYPE)"
	@echo "  LOCATION=$(LOCATION)"
	@echo "  TERRARIA_PORT=$(TERRARIA_PORT)"
	@echo "  SSH_PORT=$(SSH_PORT)"
	@echo "  SSH_USER=$(SSH_USER)"
	@echo "  BASE_IMAGE=$(BASE_IMAGE)"
	@echo "  BACKUP_DIR=$(BACKUP_DIR)"
	@echo "  BACKUP_REMOTE_PATH=$(BACKUP_REMOTE_PATH)"

.PHONY: up
up:
	@echo "==> Checking for snapshot..."
	@hcloud image list -o noheader | grep -q "$(SNAPSHOT_NAME)" || (echo "ERROR: Snapshot $(SNAPSHOT_NAME) not found!" && exit 1)
	@echo "==> Checking firewall..."
	@hcloud firewall list -o noheader | grep -q "$(FIREWALL_NAME)" || (echo "WARNING: Firewall $(FIREWALL_NAME) not found. Create it via: make firewall-create" && exit 1)
	@echo "==> Creating server $(SERVER_NAME) from snapshot $(SNAPSHOT_NAME)..."
	@hcloud server create \
		--name $(SERVER_NAME) \
		--type $(SERVER_TYPE) \
		--location $(LOCATION) \
		--image $(SNAPSHOT_NAME) \
		--firewall $(FIREWALL_NAME)
	@echo "==> Server created! Getting IP address..."
	@sleep 3
	@make ip

.PHONY: create-initial
create-initial:
	@echo "==> Checking firewall..."
	@hcloud firewall list -o noheader | grep -q "$(FIREWALL_NAME)" || (echo "WARNING: Firewall $(FIREWALL_NAME) not found. Create it via: make firewall-create" && exit 1)
	@echo "==> Creating NEW server $(SERVER_NAME) with cloud-init..."
	@hcloud server create \
		--name $(SERVER_NAME) \
		--type $(SERVER_TYPE) \
		--location $(LOCATION) \
		--image $(BASE_IMAGE) \
		--firewall $(FIREWALL_NAME) \
		--user-data-from-file cloud-init.yaml
	@echo "==> Server created! Waiting for cloud-init to complete..."
	@sleep 30
	@SERVER_IP=$$(hcloud server ip $(SERVER_NAME)) && \
	echo "IP: $$SERVER_IP" && \
	echo "" && \
	echo "==> Starting automatic deployment..." && \
	$(INITIAL_DEPLOY_SCRIPT) "$$SERVER_IP"

.PHONY: delete
delete:
	@echo "==> Checking if server exists..."
	@hcloud server describe $(SERVER_NAME) >/dev/null 2>&1 || (echo "Server $(SERVER_NAME) not found" && exit 0)
	@echo ""
	@echo "==> STEP 1/2: Creating world backup..."
	@helpers/backup-world || echo "WARNING: World backup failed"
	@echo ""
	@echo "==> STEP 2/2: Deleting server..."
	@hcloud server delete $(SERVER_NAME)
	@echo "==> Done! Server deleted, world backup created"

.PHONY: status
status:
	@hcloud server describe $(SERVER_NAME) 2>/dev/null || echo "Server $(SERVER_NAME) not found"

.PHONY: ip
ip:
	@echo "Server IP address:"
	@hcloud server ip $(SERVER_NAME)

.PHONY: firewall-create
firewall-create:
	@echo "==> Creating firewall $(FIREWALL_NAME)..."
	@hcloud firewall create \
		--name $(FIREWALL_NAME) \
		--rules-file <(echo '[{"direction": "in", "protocol": "tcp", "port": "$(SSH_PORT)", "source_ips": ["0.0.0.0/0", "::/0"]}, {"direction": "in", "protocol": "tcp", "port": "$(TERRARIA_PORT)", "source_ips": ["0.0.0.0/0", "::/0"]}]')
	@echo "==> Firewall created with rules: SSH ($(SSH_PORT)) and Terraria ($(TERRARIA_PORT))"

.PHONY: firewall-delete
firewall-delete:
	@echo "==> Deleting firewall $(FIREWALL_NAME)..."
	@hcloud firewall delete $(FIREWALL_NAME) || echo "Firewall not found or already deleted"

# ==== HELPER COMMANDS ====

.PHONY: list-snapshots
list-snapshots:
	@echo "Available snapshots:"
	@hcloud image list -t snapshot

.PHONY: list-servers
list-servers:
	@echo "All servers:"
	@hcloud server list

.PHONY: ssh
ssh:
	@echo "==> Connecting to server as $(SSH_USER)..."
	@ssh -p $(SSH_PORT) $(SSH_USER)@$$(hcloud server ip $(SERVER_NAME))

.PHONY: backup
backup:
	@echo "==> Creating Terraria files backup..."
	@TIMESTAMP=$$(date +%Y-%m-%d_%H-%M-%S) && \
	BACKUP_PATH="$(BACKUP_DIR)/$$TIMESTAMP" && \
	mkdir -p "$$BACKUP_PATH" && \
	echo "==> Copying files from server..." && \
	rsync -avz --progress \
		-e "ssh -p $(SSH_PORT) -i ~/.ssh/personal" \
		$(SSH_USER)@$$(hcloud server ip $(SERVER_NAME)):$(BACKUP_REMOTE_PATH)/ \
		"$$BACKUP_PATH/" && \
	echo "==> Backup saved to $$BACKUP_PATH"

.PHONY: snapshot
snapshot:
	@echo "==> STEP 1/2: Creating world backup..."
	@helpers/backup-world || echo "WARNING: World backup failed"
	@echo ""
	@echo "==> STEP 2/2: Creating server snapshot..."
	@SNAPSHOT_DESC="terraria-$$(date +%Y%m%d-%H%M%S)" && \
	hcloud server create-image \
		--type snapshot \
		--description "$$SNAPSHOT_DESC" \
		$(SERVER_NAME) && \
	echo "==> Snapshot created: $$SNAPSHOT_DESC"

.PHONY: server-status
server-status:
	@echo "==> Terraria server status on $(SERVER_NAME)..."
	@ssh -p $(SSH_PORT) -i ~/.ssh/personal -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		$(SSH_USER)@$$(hcloud server ip $(SERVER_NAME)) \
		'sudo systemctl status terraria --no-pager'

.PHONY: logs
logs:
	@echo "==> Last 50 lines of Terraria server logs..."
	@ssh -p $(SSH_PORT) -i ~/.ssh/personal -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		$(SSH_USER)@$$(hcloud server ip $(SERVER_NAME)) \
		'sudo journalctl -u terraria -n 50 --no-pager'

.PHONY: logs-live
logs-live:
	@echo "==> Terraria server logs in real-time (Ctrl+C to exit)..."
	@ssh -p $(SSH_PORT) -i ~/.ssh/personal -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		$(SSH_USER)@$$(hcloud server ip $(SERVER_NAME)) \
		'sudo journalctl -u terraria -f'

.PHONY: restart
restart:
	@echo "==> Restarting Terraria server..."
	@ssh -p $(SSH_PORT) -i ~/.ssh/personal -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		$(SSH_USER)@$$(hcloud server ip $(SERVER_NAME)) \
		'sudo systemctl restart terraria'
	@echo "==> Server restarted"

.PHONY: backup-world
backup-world:
	@echo "==> Creating Terraria world backup..."
	@helpers/backup-world

.PHONY: deploy-world
deploy-world:
	@helpers/deploy-world $$(hcloud server ip $(SERVER_NAME))
	@echo "==> Restarting server to apply changes..."
	@make restart
