#!/bin/bash

# Setup Script for Inventory VM
# Purpose: Install PostgreSQL, Python, PM2, and start the Inventory API
# This runs during "vagrant up inventory-vm" provisioning

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

# Require environment variables for credentials and keep safe defaults only for non-sensitive network values.
: "${INVENTORY_DB_NAME:?INVENTORY_DB_NAME is required}"
: "${INVENTORY_DB_USER:?INVENTORY_DB_USER is required}"
: "${INVENTORY_DB_PASSWORD:?INVENTORY_DB_PASSWORD is required}"
: "${BILLING_DB_NAME:?BILLING_DB_NAME is required}"
: "${BILLING_DB_USER:?BILLING_DB_USER is required}"
: "${BILLING_DB_PASSWORD:?BILLING_DB_PASSWORD is required}"
: "${RABBITMQ_USER:?RABBITMQ_USER is required}"
: "${RABBITMQ_PASSWORD:?RABBITMQ_PASSWORD is required}"
INVENTORY_DB_HOST=${INVENTORY_DB_HOST:-localhost}
INVENTORY_DB_PORT=${INVENTORY_DB_PORT:-5432}
INVENTORY_PORT=${INVENTORY_PORT:-8080}

# Keep one VM-level source of truth for environment values.
cat > /home/vagrant/.env << EOF
INVENTORY_DB_NAME=$INVENTORY_DB_NAME
INVENTORY_DB_USER=$INVENTORY_DB_USER
INVENTORY_DB_PASSWORD=$INVENTORY_DB_PASSWORD
INVENTORY_DB_HOST=$INVENTORY_DB_HOST
INVENTORY_DB_PORT=$INVENTORY_DB_PORT
BILLING_DB_NAME=$BILLING_DB_NAME
BILLING_DB_USER=$BILLING_DB_USER
BILLING_DB_PASSWORD=$BILLING_DB_PASSWORD
BILLING_DB_HOST=${BILLING_DB_HOST:-localhost}
BILLING_DB_PORT=${BILLING_DB_PORT:-5432}
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
RABBITMQ_HOST=${RABBITMQ_HOST:-192.168.56.12}
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
RABBITMQ_QUEUE=${RABBITMQ_QUEUE:-billing_queue}
INVENTORY_PORT=$INVENTORY_PORT
BILLING_PORT=${BILLING_PORT:-8081}
GATEWAY_PORT=${GATEWAY_PORT:-3000}
GATEWAY_IP=${GATEWAY_IP:-192.168.56.10}
INVENTORY_IP=${INVENTORY_IP:-192.168.56.11}
BILLING_IP=${BILLING_IP:-192.168.56.12}
EOF
chmod 600 /home/vagrant/.env

echo "=================================================="
echo "🎬 SETTING UP INVENTORY-VM"
echo "=================================================="

# ============================================================
# Step 1: Update System Packages
# ============================================================
echo "📦 [1/11] Updating system packages..."
wait_for_apt_lock
dpkg --configure -a || true
apt-get install -f -y || true
apt-get update -y

# ============================================================
# Step 2: Install Python 3 and pip
# ============================================================
echo "🐍 [2/11] Installing Python 3 and pip..."
wait_for_apt_lock
apt-get install -y --no-install-recommends python3 python3-pip python3-venv

# ============================================================
# Step 3: Install PostgreSQL
# ============================================================
echo "🗄️  [3/11] Installing PostgreSQL..."
wait_for_apt_lock
apt-get install -y --no-install-recommends postgresql postgresql-contrib

# ============================================================
# Step 4: Start PostgreSQL Service
# ============================================================
echo "🚀 [4/11] Starting PostgreSQL service..."
systemctl start postgresql
systemctl enable postgresql

# ============================================================
# Step 5: Create Database User and Database
# ============================================================
echo "👤 [5/11] Creating PostgreSQL user and database..."

# Create user with password
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$INVENTORY_DB_USER'" | grep -q 1; then
	sudo -u postgres psql -c "CREATE USER $INVENTORY_DB_USER WITH ENCRYPTED PASSWORD '$INVENTORY_DB_PASSWORD';"
fi

# Create database
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$INVENTORY_DB_NAME'" | grep -q 1; then
	sudo -u postgres psql -c "CREATE DATABASE $INVENTORY_DB_NAME;"
fi

# Grant privileges on database
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $INVENTORY_DB_NAME TO $INVENTORY_DB_USER;"

# Grant schema permissions (important for table creation!)
sudo -u postgres psql -d $INVENTORY_DB_NAME -c "GRANT USAGE ON SCHEMA public TO $INVENTORY_DB_USER;"
sudo -u postgres psql -d $INVENTORY_DB_NAME -c "GRANT CREATE ON SCHEMA public TO $INVENTORY_DB_USER;"

echo "✅ User '$INVENTORY_DB_USER' and database '$INVENTORY_DB_NAME' created successfully"

# ============================================================
# Step 6: Install Node.js and PM2
# ============================================================
echo "📦 [6/11] Installing Node.js and PM2..."
wait_for_apt_lock
apt-get install -y --no-install-recommends nodejs npm
npm install -g pm2

# ============================================================
# Step 7: Navigate to App Directory
# ============================================================
echo "📂 [7/11] Navigating to inventory-app directory..."
cd /home/vagrant/srcs/inventory-app

# ============================================================
# Step 8: Install Python Dependencies
# ============================================================
echo "📚 [8/11] Installing Python dependencies..."
pip3 install --break-system-packages --ignore-installed -r requirements.txt

# ============================================================
# Step 9: Use VM root .env only
# ============================================================
echo "🔐 [9/11] Using /home/vagrant/.env as the only runtime env source..."

# ============================================================
# Step 10: Start Application with PM2
# ============================================================
echo "🚀 [10/11] Starting Inventory API with PM2..."
cd /home/vagrant/srcs/inventory-app
pm2 restart inventory_app || pm2 start server.py --name inventory_app --interpreter python3

# ============================================================
# Step 11: Save PM2 Process List and Enable Startup
# ============================================================
echo "💾 [11/11] Saving PM2 configuration for startup..."
pm2 save
pm2 startup systemd -u vagrant --hp /home/vagrant

echo "=================================================="
echo "✅ INVENTORY-VM SETUP COMPLETE"
echo "=================================================="
echo ""
echo "✅ PostgreSQL: Running on port $INVENTORY_DB_PORT"
echo "✅ Database: $INVENTORY_DB_NAME"
echo "✅ API: Running on port $INVENTORY_PORT"
echo "✅ PM2: inventory_app process registered"
echo ""
echo "To SSH into this VM:"
echo "  vagrant ssh inventory-vm"
echo ""
echo "To view logs:"
echo "  sudo pm2 logs inventory_app"
echo ""
