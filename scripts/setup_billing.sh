#!/bin/bash

# Setup Script for Billing VM
# Purpose: Install PostgreSQL, RabbitMQ, Python, PM2, and start the Billing API
# This runs during "vagrant up billing-vm" provisioning

set -e  # Exit on first error

echo "=================================================="
echo "💳 SETTING UP BILLING-VM"
echo "=================================================="

# ============================================================
# Step 1: Update System Packages
# ============================================================
echo "📦 [1/13] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# ============================================================
# Step 2: Install Python 3 and pip
# ============================================================
echo "🐍 [2/13] Installing Python 3 and pip..."
apt-get install -y python3 python3-pip python3-venv

# ============================================================
# Step 3: Install PostgreSQL
# ============================================================
echo "🗄️  [3/13] Installing PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

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
sudo -u postgres psql -c "CREATE USER $BILLING_DB_USER WITH ENCRYPTED PASSWORD '$BILLING_DB_PASSWORD';"

# Create database
sudo -u postgres psql -c "CREATE DATABASE $BILLING_DB_NAME;"

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
apt-get install -y rabbitmq-server

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
rabbitmqctl add_user $RABBITMQ_USER $RABBITMQ_PASSWORD

# Set user tags (administrator)
rabbitmqctl set_user_tags $RABBITMQ_USER administrator

# Set permissions (can read, write, and configure on all exchanges/queues)
rabbitmqctl set_permissions -p / $RABBITMQ_USER '.*' '.*' '.*'

# Delete guest user (default, for security)
rabbitmqctl delete_user guest

echo "✅ RabbitMQ user '$RABBITMQ_USER' configured successfully"

# ============================================================
# Step 9: Install Node.js and PM2
# ============================================================
echo "📦 [9/13] Installing Node.js and PM2..."
apt-get install -y nodejs npm
npm install -g pm2

# ============================================================
# Step 10: Navigate to App Directory and Install Dependencies
# ============================================================
echo "📂 [10/13] Navigating to billing-app directory..."
cd /home/vagrant/srcs/billing-app

echo "📚 Installing Python dependencies..."
pip3 install -r requirements.txt

# ============================================================
# Step 11: Create .env File Inside App Directory
# ============================================================
echo "🔐 [11/13] Creating .env file for the application..."
cat > /home/vagrant/srcs/billing-app/.env << EOF
# Billing Database Configuration
BILLING_DB_NAME=$BILLING_DB_NAME
BILLING_DB_USER=$BILLING_DB_USER
BILLING_DB_PASSWORD=$BILLING_DB_PASSWORD
BILLING_DB_HOST=$BILLING_DB_HOST
BILLING_DB_PORT=$BILLING_DB_PORT

# RabbitMQ Configuration
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
RABBITMQ_HOST=$RABBITMQ_HOST
RABBITMQ_PORT=$RABBITMQ_PORT
RABBITMQ_QUEUE=$RABBITMQ_QUEUE

# API Server Port
BILLING_PORT=$BILLING_PORT
EOF

chmod 600 /home/vagrant/srcs/billing-app/.env

# ============================================================
# Step 12: Start Application with PM2
# ============================================================
echo "🚀 [12/13] Starting Billing API with PM2..."
cd /home/vagrant/srcs/billing-app
pm2 start server.py --name billing_app --interpreter python3

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
