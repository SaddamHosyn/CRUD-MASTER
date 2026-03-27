#!/bin/bash

# Setup Script for Inventory VM
# Purpose: Install PostgreSQL, Python, PM2, and start the Inventory API
# This runs during "vagrant up inventory-vm" provisioning

set -e  # Exit on first error

echo "=================================================="
echo "🎬 SETTING UP INVENTORY-VM"
echo "=================================================="

# ============================================================
# Step 1: Update System Packages
# ============================================================
echo "📦 [1/11] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# ============================================================
# Step 2: Install Python 3 and pip
# ============================================================
echo "🐍 [2/11] Installing Python 3 and pip..."
apt-get install -y python3 python3-pip python3-venv

# ============================================================
# Step 3: Install PostgreSQL
# ============================================================
echo "🗄️  [3/11] Installing PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

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
sudo -u postgres psql -c "CREATE USER $INVENTORY_DB_USER WITH ENCRYPTED PASSWORD '$INVENTORY_DB_PASSWORD';"

# Create database
sudo -u postgres psql -c "CREATE DATABASE $INVENTORY_DB_NAME;"

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
apt-get install -y nodejs npm
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
pip3 install -r requirements.txt

# ============================================================
# Step 9: Create .env File Inside App Directory
# ============================================================
echo "🔐 [9/11] Creating .env file for the application..."
cat > /home/vagrant/srcs/inventory-app/.env << EOF
# Inventory Database Configuration
INVENTORY_DB_NAME=$INVENTORY_DB_NAME
INVENTORY_DB_USER=$INVENTORY_DB_USER
INVENTORY_DB_PASSWORD=$INVENTORY_DB_PASSWORD
INVENTORY_DB_HOST=$INVENTORY_DB_HOST
INVENTORY_DB_PORT=$INVENTORY_DB_PORT

# API Server Port
INVENTORY_PORT=$INVENTORY_PORT
EOF

chmod 600 /home/vagrant/srcs/inventory-app/.env

# ============================================================
# Step 10: Start Application with PM2
# ============================================================
echo "🚀 [10/11] Starting Inventory API with PM2..."
cd /home/vagrant/srcs/inventory-app
pm2 start server.py --name inventory_app --interpreter python3

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
