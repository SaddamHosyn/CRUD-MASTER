#!/bin/bash

# Setup Script for Gateway VM
# Purpose: Install Python, PM2, and start the API Gateway
# This runs during "vagrant up gateway-vm" provisioning

set -e  # Exit on first error

# Prevent apt from opening interactive prompts during provisioning.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

wait_for_apt_lock() {
	while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
				fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
		echo "⏳ Waiting for apt/dpkg lock to be released..."
		sleep 5
	done
}

# Environment variables are injected by Vagrant from the root .env.

# Require credential environment variables and keep safe defaults only for non-sensitive network values.
: "${INVENTORY_DB_NAME:?INVENTORY_DB_NAME is required}"
: "${INVENTORY_DB_USER:?INVENTORY_DB_USER is required}"
: "${INVENTORY_DB_PASSWORD:?INVENTORY_DB_PASSWORD is required}"
: "${BILLING_DB_NAME:?BILLING_DB_NAME is required}"
: "${BILLING_DB_USER:?BILLING_DB_USER is required}"
: "${BILLING_DB_PASSWORD:?BILLING_DB_PASSWORD is required}"
: "${RABBITMQ_USER:?RABBITMQ_USER is required}"
: "${RABBITMQ_PASSWORD:?RABBITMQ_PASSWORD is required}"
GATEWAY_PORT=${GATEWAY_PORT:-3000}
INVENTORY_IP=${INVENTORY_IP:-192.168.56.11}
INVENTORY_PORT=${INVENTORY_PORT:-8080}
RABBITMQ_HOST=${RABBITMQ_HOST:-192.168.56.12}
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
RABBITMQ_QUEUE=${RABBITMQ_QUEUE:-billing_queue}

# Keep one VM-level source of truth for environment values.
cat > /home/vagrant/.env << EOF
INVENTORY_DB_NAME=$INVENTORY_DB_NAME
INVENTORY_DB_USER=$INVENTORY_DB_USER
INVENTORY_DB_PASSWORD=$INVENTORY_DB_PASSWORD
INVENTORY_DB_HOST=${INVENTORY_DB_HOST:-localhost}
INVENTORY_DB_PORT=${INVENTORY_DB_PORT:-5432}
BILLING_DB_NAME=$BILLING_DB_NAME
BILLING_DB_USER=$BILLING_DB_USER
BILLING_DB_PASSWORD=$BILLING_DB_PASSWORD
BILLING_DB_HOST=${BILLING_DB_HOST:-localhost}
BILLING_DB_PORT=${BILLING_DB_PORT:-5432}
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
RABBITMQ_HOST=$RABBITMQ_HOST
RABBITMQ_PORT=$RABBITMQ_PORT
RABBITMQ_QUEUE=$RABBITMQ_QUEUE
INVENTORY_PORT=$INVENTORY_PORT
BILLING_PORT=${BILLING_PORT:-8081}
GATEWAY_PORT=$GATEWAY_PORT
GATEWAY_IP=${GATEWAY_IP:-192.168.56.10}
INVENTORY_IP=$INVENTORY_IP
BILLING_IP=${BILLING_IP:-192.168.56.12}
EOF
chmod 600 /home/vagrant/.env

echo "=================================================="
echo "🚪 SETTING UP GATEWAY-VM"
echo "=================================================="

# ============================================================
# Step 1: Update System Packages
# ============================================================
echo "📦 [1/8] Updating system packages..."
wait_for_apt_lock
dpkg --configure -a || true
apt-get install -f -y || true
apt-get update -y

# ============================================================
# Step 2: Install Python 3 and pip
# ============================================================
echo "🐍 [2/8] Installing Python 3 and pip..."
wait_for_apt_lock
apt-get install -y --no-install-recommends python3 python3-pip python3-venv

# ============================================================
# Step 3: Install Node.js and PM2
# ============================================================
echo "📦 [3/8] Installing Node.js and PM2..."
wait_for_apt_lock
apt-get install -y --no-install-recommends nodejs npm
npm install -g pm2

# ============================================================
# Step 4: Navigate to Gateway App Directory
# ============================================================
echo "📂 [4/8] Navigating to api-gateway-app directory..."
cd /home/vagrant/srcs/api-gateway-app

# ============================================================
# Step 5: Install Python Dependencies
# ============================================================
echo "📚 [5/8] Installing Python dependencies..."
pip3 install --break-system-packages --ignore-installed -r requirements.txt

# ============================================================
# Step 6: Use VM root .env only
# ============================================================
echo "🔐 [6/8] Using /home/vagrant/.env as the only runtime env source..."

# ============================================================
# Step 7: Start Application with PM2
# ============================================================
echo "🚀 [7/8] Starting API Gateway with PM2..."
cd /home/vagrant/srcs/api-gateway-app
pm2 restart api_gateway || pm2 start server.py --name api_gateway --interpreter python3

# ============================================================
# Step 8: Save PM2 Process List and Enable Startup
# ============================================================
echo "💾 [8/8] Saving PM2 configuration for startup..."
pm2 save
pm2 startup systemd -u vagrant --hp /home/vagrant

echo "=================================================="
echo "✅ GATEWAY-VM SETUP COMPLETE"
echo "=================================================="
echo ""
echo "✅ API Gateway: Running on port $GATEWAY_PORT"
echo "✅ Proxy Target: Inventory API at $INVENTORY_IP:$INVENTORY_PORT"
echo "✅ RabbitMQ: Connected to $RABBITMQ_HOST:$RABBITMQ_PORT"
echo "✅ PM2: api_gateway process registered"
echo ""
echo "To SSH into this VM:"
echo "  vagrant ssh gateway-vm"
echo ""
echo "To view logs:"
echo "  sudo pm2 logs api_gateway"
echo ""
echo "To test the gateway:"
echo "  curl http://192.168.56.10:3000/api/movies"
echo ""
