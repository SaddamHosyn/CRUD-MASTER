# CRUD Master Vagrant Configuration - VirtualBox Provider
# Three separate Ubuntu VMs running on VirtualBox with private network
# 
# Services:
# - gateway-vm: API Gateway (port 3000)
# - inventory-vm: Inventory API + PostgreSQL (port 8080)
# - billing-vm: Billing API + RabbitMQ + PostgreSQL (port 8081)

# Load root .env once; this is the single source of truth.
env_vars = {}
if File.exist?('.env')
  File.foreach('.env') do |line|
    next if line.strip.empty? || line.strip.start_with?('#')

    key, value = line.strip.split('=', 2)
    env_vars[key] = value if key && value
  end
end

Vagrant.configure('2') do |config|
  # Global VirtualBox settings
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 2
  end

  # ============================================================
  # VM 1: GATEWAY-VM (API Gateway on port 3000)
  # ============================================================
  config.vm.define "gateway-vm" do |gateway|
    gateway.vm.box = "hashicorp-education/ubuntu-24-04"
    gateway.vm.hostname = "gateway-vm"
    gateway.vm.network "private_network", ip: "192.168.56.10"
    gateway.vm.network "forwarded_port", guest: 3000, host: 3000
    
    gateway.vm.synced_folder "./srcs", "/home/vagrant/srcs", type: "rsync", rsync__auto: true
    
    gateway.vm.provision "shell", path: "scripts/setup_gateway.sh", env: env_vars
  end

  # ============================================================
  # VM 2: INVENTORY-VM (Inventory API + PostgreSQL on port 8080)
  # ============================================================
  config.vm.define "inventory-vm" do |inventory|
    inventory.vm.box = "hashicorp-education/ubuntu-24-04"
    inventory.vm.hostname = "inventory-vm"
    inventory.vm.network "private_network", ip: "192.168.56.11"
    
    inventory.vm.synced_folder "./srcs", "/home/vagrant/srcs", type: "rsync", rsync__auto: true
    
    inventory.vm.provision "shell", path: "scripts/setup_inventory.sh", env: env_vars
  end

  # ============================================================
  # VM 3: BILLING-VM (Billing API + RabbitMQ + PostgreSQL)
  # ============================================================
  config.vm.define "billing-vm" do |billing|
    billing.vm.box = "hashicorp-education/ubuntu-24-04"
    billing.vm.hostname = "billing-vm"
    billing.vm.network "private_network", ip: "192.168.56.12"
    billing.vm.network "forwarded_port", guest: 5672, host: 5672
    billing.vm.network "forwarded_port", guest: 15672, host: 15672
    
    billing.vm.synced_folder "./srcs", "/home/vagrant/srcs", type: "rsync", rsync__auto: true
    
    billing.vm.provision "shell", path: "scripts/setup_billing.sh", env: env_vars
  end
  
end