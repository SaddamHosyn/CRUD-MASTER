#!/bin/bash
# Restart the inventory API service
cd /home/vagrant/srcs/inventory-app
pkill -f server.py || true
sleep 2
source /home/vagrant/.env 2>/dev/null || true
nohup python3 server.py > /tmp/inventory.log 2>&1 &
sleep 3
ss -tlnp | grep 8080
echo "RESTART_DONE"
