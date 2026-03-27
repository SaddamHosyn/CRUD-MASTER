#!/bin/bash

# Setup Script for Gateway VM
# Purpose: Install Python, PM2, and start the API Gateway
# This runs during "vagrant up gateway-vm" provisioning

set -e  # Exit on first error

echo "=================================================="
echo "🚪 SETTING UP GATEWAY-VM"
echo "=================================================="

# ============================================================
# Step 1: Update System Packages
# ============================================================
echo "📦 [1/8] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# ============================================================
# Step 2: Install Python 3 and pip
# ============================================================
echo "🐍 [2/8] Installing Python 3 and pip..."
apt-get install -y python3 python3-pip python3-venv

# ============================================================
# Step 3: Install Node.js and PM2
# ============================================================
echo "📦 [3/8] Installing Node.js and PM2..."
apt-get install -y nodejs npm
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
pip3 install -r requirements.txt

# ============================================================
# Step 6: Create .env File Inside App Directory
# ============================================================
echo "🔐 [6/8] Creating .env file for the gateway application..."
cat > /home/vagrant/srcs/api-gateway-app/.env << EOF
# Inventory API Configuration (for HTTP proxy)
INVENTORY_IP=$INVENTORY_IP
INVENTORY_PORT=$INVENTORY_PORT

# RabbitMQ Configuration (for message publishing)
RABBITMQ_HOST=$RABBITMQ_HOST
RABBITMQ_PORT=$RABBITMQ_PORT
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
RABBITMQ_QUEUE=$RABBITMQ_QUEUE

# API Gateway Port
GATEWAY_PORT=$GATEWAY_PORT
EOF

chmod 600 /home/vagrant/srcs/api-gateway-app/.env

# ============================================================
# Step 7: Start Application with PM2
# ============================================================
echo "🚀 [7/8] Starting API Gateway with PM2..."
cd /home/vagrant/srcs/api-gateway-app
pm2 start server.py --name api_gateway --interpreter python3

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
