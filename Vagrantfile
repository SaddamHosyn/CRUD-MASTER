# CRUD Master Vagrant Configuration
# This file defines three virtual machines for the microservices project:
# - gateway-vm: API Gateway (port 3000)
# - inventory-vm: Inventory API with PostgreSQL (port 8080)
# - billing-vm: Billing API with RabbitMQ and PostgreSQL (port 8081)

# Load environment variables from .env file
env = {}
File.foreach('.env') do |line|
  # Skip comments and empty lines
  next if line.strip.start_with?('#') || line.strip.empty?
  
  # Split on first '=' to handle values with '=' in them
  key, value = line.strip.split('=', 2)
  env[key] = value
end

# Define Vagrant configuration
Vagrant.configure('2') do |config|
  
  # ============================================================
  # VM 1: GATEWAY-VM (API Gateway)
  # ============================================================
  # Purpose: Single entry point for all client requests
  # Proxies /api/movies/* to inventory-vm
  # Publishes /api/billing to RabbitMQ on billing-vm
  # Port: 3000
  
  config.vm.define "gateway-vm" do |gateway|
    gateway.vm.box = "ubuntu/focal64"
    gateway.vm.hostname = "gateway-vm"
    
    # Static IP for private network (used by other VMs to reach gateway)
    gateway.vm.network "private_network", ip: env['GATEWAY_IP']
    
    # Sync srcs folder from host to VM
    # /Users/.../srcs → /home/vagrant/srcs
    gateway.vm.synced_folder "./srcs", "/home/vagrant/srcs"
    
    # Run setup script for gateway during provisioning
    gateway.vm.provision "shell", path: "scripts/setup_gateway.sh", env: {
      "INVENTORY_IP"        => env['INVENTORY_IP'],
      "INVENTORY_PORT"      => env['INVENTORY_PORT'],
      "RABBITMQ_HOST"       => env['RABBITMQ_HOST'],
      "RABBITMQ_PORT"       => env['RABBITMQ_PORT'],
      "RABBITMQ_USER"       => env['RABBITMQ_USER'],
      "RABBITMQ_PASSWORD"   => env['RABBITMQ_PASSWORD'],
      "RABBITMQ_QUEUE"      => env['RABBITMQ_QUEUE'],
      "GATEWAY_PORT"        => env['GATEWAY_PORT']
    }
    
    # VirtualBox-specific settings
    gateway.vm.provider "virtualbox" do |vb|
      vb.name = "gateway-vm"
      vb.memory = 1024  # 1 GB RAM
      vb.cpus = 1
    end
  end
  
  # ============================================================
  # VM 2: INVENTORY-VM (Inventory API + PostgreSQL)
  # ============================================================
  # Purpose: REST API for movie CRUD operations
  # Database: PostgreSQL (movies table)
  # Port: 8080
  
  config.vm.define "inventory-vm" do |inventory|
    inventory.vm.box = "ubuntu/focal64"
    inventory.vm.hostname = "inventory-vm"
    
    # Static IP for private network
    inventory.vm.network "private_network", ip: env['INVENTORY_IP']
    
    # Sync srcs folder
    inventory.vm.synced_folder "./srcs", "/home/vagrant/srcs"
    
    # Run setup script for inventory
    inventory.vm.provision "shell", path: "scripts/setup_inventory.sh", env: {
      "INVENTORY_DB_NAME"     => env['INVENTORY_DB_NAME'],
      "INVENTORY_DB_USER"     => env['INVENTORY_DB_USER'],
      "INVENTORY_DB_PASSWORD" => env['INVENTORY_DB_PASSWORD'],
      "INVENTORY_DB_HOST"     => env['INVENTORY_DB_HOST'],
      "INVENTORY_DB_PORT"     => env['INVENTORY_DB_PORT'],
      "INVENTORY_PORT"        => env['INVENTORY_PORT']
    }
    
    # VirtualBox-specific settings
    inventory.vm.provider "virtualbox" do |vb|
      vb.name = "inventory-vm"
      vb.memory = 1024  # 1 GB RAM (PostgreSQL + Flask)
      vb.cpus = 1
    end
  end
  
  # ============================================================
  # VM 3: BILLING-VM (Billing API + RabbitMQ + PostgreSQL)
  # ============================================================
  # Purpose: Message-driven service that consumes from RabbitMQ
  # Database: PostgreSQL (orders table)
  # Message Queue: RabbitMQ (billing_queue)
  # Port: 8081 (for future HTTP endpoints)
  
  config.vm.define "billing-vm" do |billing|
    billing.vm.box = "ubuntu/focal64"
    billing.vm.hostname = "billing-vm"
    
    # Static IP for private network (RabbitMQ accessed via this IP)
    billing.vm.network "private_network", ip: env['BILLING_IP']
    
    # Sync srcs folder
    billing.vm.synced_folder "./srcs", "/home/vagrant/srcs"
    
    # Run setup script for billing
    billing.vm.provision "shell", path: "scripts/setup_billing.sh", env: {
      "BILLING_DB_NAME"       => env['BILLING_DB_NAME'],
      "BILLING_DB_USER"       => env['BILLING_DB_USER'],
      "BILLING_DB_PASSWORD"   => env['BILLING_DB_PASSWORD'],
      "BILLING_DB_HOST"       => env['BILLING_DB_HOST'],
      "BILLING_DB_PORT"       => env['BILLING_DB_PORT'],
      "RABBITMQ_USER"         => env['RABBITMQ_USER'],
      "RABBITMQ_PASSWORD"     => env['RABBITMQ_PASSWORD'],
      "RABBITMQ_PORT"         => env['RABBITMQ_PORT'],
      "RABBITMQ_QUEUE"        => env['RABBITMQ_QUEUE'],
      "BILLING_PORT"          => env['BILLING_PORT']
    }
    
    # VirtualBox-specific settings
    billing.vm.provider "virtualbox" do |vb|
      vb.name = "billing-vm"
      vb.memory = 1024  # 1 GB RAM (RabbitMQ + PostgreSQL + Python)
      vb.cpus = 1
    end
  end
  
end
