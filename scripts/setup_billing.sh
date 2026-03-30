#!/bin/bash

# Setup Script for Billing VM
# Purpose: Install PostgreSQL, RabbitMQ, Python, PM2, and start the Billing API
# This runs during "vagrant up billing-vm" provisioning

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

# Set defaults if not provided
BILLING_DB_NAME=${BILLING_DB_NAME:-orders}
BILLING_DB_USER=${BILLING_DB_USER:-billing_user}
BILLING_DB_PASSWORD=${BILLING_DB_PASSWORD:-billing_pass}
BILLING_DB_HOST=${BILLING_DB_HOST:-localhost}
BILLING_DB_PORT=${BILLING_DB_PORT:-5432}
BILLING_PORT=${BILLING_PORT:-8081}
RABBITMQ_HOST=${RABBITMQ_HOST:-192.168.56.12}
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
RABBITMQ_USER=${RABBITMQ_USER:-billing_rmq}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-billing_rmq_pass}
RABBITMQ_QUEUE=${RABBITMQ_QUEUE:-billing_queue}

# Keep one VM-level source of truth for environment values.
cat > /home/vagrant/.env << EOF
INVENTORY_DB_NAME=${INVENTORY_DB_NAME:-movies}
INVENTORY_DB_USER=${INVENTORY_DB_USER:-inventory_user}
INVENTORY_DB_PASSWORD=${INVENTORY_DB_PASSWORD:-inventory_pass}
INVENTORY_DB_HOST=${INVENTORY_DB_HOST:-localhost}
INVENTORY_DB_PORT=${INVENTORY_DB_PORT:-5432}
BILLING_DB_NAME=$BILLING_DB_NAME
BILLING_DB_USER=$BILLING_DB_USER
BILLING_DB_PASSWORD=$BILLING_DB_PASSWORD
BILLING_DB_HOST=$BILLING_DB_HOST
BILLING_DB_PORT=$BILLING_DB_PORT
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
RABBITMQ_HOST=$RABBITMQ_HOST
RABBITMQ_PORT=$RABBITMQ_PORT
RABBITMQ_QUEUE=$RABBITMQ_QUEUE
INVENTORY_PORT=${INVENTORY_PORT:-8080}
BILLING_PORT=$BILLING_PORT
GATEWAY_PORT=${GATEWAY_PORT:-3000}
GATEWAY_IP=${GATEWAY_IP:-192.168.56.10}
INVENTORY_IP=${INVENTORY_IP:-192.168.56.11}
BILLING_IP=${BILLING_IP:-192.168.56.12}
EOF
chmod 600 /home/vagrant/.env

echo "=================================================="
echo "💳 SETTING UP BILLING-VM"
echo "=================================================="

# ============================================================
# Step 1: Update System Packages
# ============================================================
echo "📦 [1/13] Updating system packages..."
wait_for_apt_lock
dpkg --configure -a || true
apt-get install -f -y || true
apt-get update -y

# ============================================================
# Step 2: Install Python 3 and pip
# ============================================================
echo "🐍 [2/13] Installing Python 3 and pip..."
wait_for_apt_lock
apt-get install -y --no-install-recommends python3 python3-pip python3-venv python3-dev libpq-dev build-essential

# ============================================================
# Step 3: Install PostgreSQL
# ============================================================
echo "🗄️  [3/13] Installing PostgreSQL..."
wait_for_apt_lock
apt-get install -y --no-install-recommends postgresql postgresql-contrib

# ============================================================
# Step 4: Start PostgreSQL Service
# ============================================================
echo "🚀 [4/13] Starting PostgreSQL service..."
systemctl start postgresql
systemctl enable postgresql

# ============================================================
# Step 5: Create Billing Database User and Database
# ============================================================
echo "👤 [5/13] Creating billing PostgreSQL user and database..."

# Create user with password
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$BILLING_DB_USER'" | grep -q 1; then
	sudo -u postgres psql -c "CREATE USER $BILLING_DB_USER WITH ENCRYPTED PASSWORD '$BILLING_DB_PASSWORD';"
fi

# Create database
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$BILLING_DB_NAME'" | grep -q 1; then
	sudo -u postgres psql -c "CREATE DATABASE $BILLING_DB_NAME;"
fi

# Grant privileges on database
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $BILLING_DB_NAME TO $BILLING_DB_USER;"

# Grant schema permissions
sudo -u postgres psql -d $BILLING_DB_NAME -c "GRANT USAGE ON SCHEMA public TO $BILLING_DB_USER;"
sudo -u postgres psql -d $BILLING_DB_NAME -c "GRANT CREATE ON SCHEMA public TO $BILLING_DB_USER;"

echo "✅ User '$BILLING_DB_USER' and database '$BILLING_DB_NAME' created successfully"

# ============================================================
# Step 6: Install RabbitMQ
# ============================================================
echo "🐰 [6/13] Installing RabbitMQ..."
wait_for_apt_lock
apt-get install -y --no-install-recommends rabbitmq-server

# ============================================================
# Step 7: Start RabbitMQ Service
# ============================================================
echo "🚀 [7/13] Starting RabbitMQ service..."
systemctl start rabbitmq-server
systemctl enable rabbitmq-server

# ============================================================
# Step 8: Configure RabbitMQ User
# ============================================================
echo "🔐 [8/13] Configuring RabbitMQ user..."

# Add RabbitMQ user
if rabbitmqctl list_users | awk '{print $1}' | grep -qx "$RABBITMQ_USER"; then
	rabbitmqctl change_password $RABBITMQ_USER $RABBITMQ_PASSWORD
else
	rabbitmqctl add_user $RABBITMQ_USER $RABBITMQ_PASSWORD
fi

# Set user tags (administrator)
rabbitmqctl set_user_tags $RABBITMQ_USER administrator

# Set permissions (can read, write, and configure on all exchanges/queues)
rabbitmqctl set_permissions -p / $RABBITMQ_USER '.*' '.*' '.*'

# Delete guest user only if using a different custom user
if [ "$RABBITMQ_USER" != "guest" ] && rabbitmqctl list_users | awk '{print $1}' | grep -qx guest; then
	rabbitmqctl delete_user guest
fi

echo "✅ RabbitMQ user '$RABBITMQ_USER' configured successfully"

# ============================================================
# Step 9: Install Node.js and PM2
# ============================================================
echo "📦 [9/13] Installing Node.js and PM2..."
wait_for_apt_lock
apt-get install -y --no-install-recommends nodejs npm
npm install -g pm2

# ============================================================
# Step 10: Navigate to App Directory and Install Dependencies
# ============================================================
echo "📂 [10/13] Navigating to billing-app directory..."
cd /home/vagrant/srcs/billing-app

echo "📚 Installing Python dependencies..."
pip3 install --break-system-packages --ignore-installed -r requirements.txt

# ============================================================
# Step 11: Use VM root .env only
# ============================================================
echo "🔐 [11/13] Using /home/vagrant/.env as the only runtime env source..."

# ============================================================
# Step 12: Start Application with PM2
# ============================================================
echo "🚀 [12/13] Starting Billing API with PM2..."
cd /home/vagrant/srcs/billing-app
pm2 restart billing_app || pm2 start server.py --name billing_app --interpreter python3

# ============================================================
# Step 13: Save PM2 Process List and Enable Startup
# ============================================================
echo "💾 [13/13] Saving PM2 configuration for startup..."
pm2 save
pm2 startup systemd -u vagrant --hp /home/vagrant

echo "=================================================="
echo "✅ BILLING-VM SETUP COMPLETE"
echo "=================================================="
echo ""
echo "✅ PostgreSQL: Running on port $BILLING_DB_PORT"
echo "✅ Database: $BILLING_DB_NAME"
echo "✅ RabbitMQ: Running on port $RABBITMQ_PORT"
echo "✅ Queue: $RABBITMQ_QUEUE"
echo "✅ PM2: billing_app process registered"
echo ""
echo "To SSH into this VM:"
echo "  vagrant ssh billing-vm"
echo ""
echo "To view logs:"
echo "  sudo pm2 logs billing_app"
echo ""
echo "To monitor RabbitMQ:"
echo "  sudo rabbitmqctl list_queues"
echo "  sudo rabbitmqctl status"
echo ""
