#!/bin/bash

# CRUD Master Local Testing Startup Script
# Starts all 3 microservices with proper environment variables

PROJECT_ROOT="/Users/saddam.hussain/Desktop/CRUD-MASTER"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  CRUD Master - Local Microservices Startup                    ║"
echo "║  Date: $(date '+%B %d, %Y')                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Kill any existing processes
echo "🧹 Cleaning up old processes..."
pkill -f "python3 server.py" 2>/dev/null || true
sleep 2

# Load environment
echo "📝 Loading environment from .env..."
set -a
source "$PROJECT_ROOT/.env"
set +a

echo "✅ Environment loaded:"
echo "   - INVENTORY_IP: $INVENTORY_IP"
echo "   - RABBITMQ_HOST: $RABBITMQ_HOST"
echo "   - Ports: $INVENTORY_PORT, $BILLING_PORT, $GATEWAY_PORT"
echo ""

# Create log directory
mkdir -p "$PROJECT_ROOT/logs"

# Start Inventory API
echo "🚀 Starting Inventory API (port $INVENTORY_PORT)..."
cd "$PROJECT_ROOT/srcs/inventory-app"
python3 server.py > "$PROJECT_ROOT/logs/inventory-api.log" 2>&1 &
INVENTORY_PID=$!
echo "   PID: $INVENTORY_PID"
sleep 3

# Check if service is running
if lsof -i :$INVENTORY_PORT >/dev/null 2>&1; then
    echo "   ✅ Inventory API is running"
else
    echo "   ❌ Failed to start Inventory API"
    echo "   Check log: tail -f $PROJECT_ROOT/logs/inventory-api.log"
fi
echo ""

# Start Billing API
echo "🚀 Starting Billing API - RabbitMQ Consumer (port $BILLING_PORT)..."
cd "$PROJECT_ROOT/srcs/billing-app"
python3 server.py > "$PROJECT_ROOT/logs/billing-api.log" 2>&1 &
BILLING_PID=$!
echo "   PID: $BILLING_PID"
sleep 3

# Check if service is running
if lsof -i :$BILLING_PORT >/dev/null 2>&1; then
    echo "   ✅ Billing API is running"
else
    echo "   ℹ️  Billing API may still be starting (RabbitMQ consumer)"
fi
echo ""

# Start API Gateway
echo "🚀 Starting API Gateway (port $GATEWAY_PORT)..."
cd "$PROJECT_ROOT/srcs/api-gateway-app"
python3 server.py > "$PROJECT_ROOT/logs/api-gateway.log" 2>&1 &
GATEWAY_PID=$!
echo "   PID: $GATEWAY_PID"
sleep 3

# Check if service is running
if lsof -i :$GATEWAY_PORT >/dev/null 2>&1; then
    echo "   ✅ API Gateway is running"
else
    echo "   ❌ Failed to start API Gateway"
    echo "   Check log: tail -f $PROJECT_ROOT/logs/api-gateway.log"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#
echo ""
echo "✅ All services started!"
echo ""
echo "📝 Available endpoints:"
echo "   • Health: http://localhost:$GATEWAY_PORT/health"
echo "   • Movies: http://localhost:$GATEWAY_PORT/api/movies"
echo "   • Billing: http://localhost:$GATEWAY_PORT/api/billing"
echo ""
echo "📊 Service logs:"
echo "   • Inventory: tail -f $PROJECT_ROOT/logs/inventory-api.log"
echo "   • Billing: tail -f $PROJECT_ROOT/logs/billing-api.log"
echo "   • Gateway: tail -f $PROJECT_ROOT/logs/api-gateway.log"
echo ""
echo "🧪 To run tests:"
echo "   bash $PROJECT_ROOT/test_local.sh"
echo ""
echo "⚠️  Press Ctrl+C to stop this script (services will continue running)"
echo "   To stop all services: pkill -f 'python3 server.py'"
echo ""
