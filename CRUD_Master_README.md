# CRUD Master — Microservices API Infrastructure
### Complete Step-by-Step Project Guide
**Stack: Python | Flask | PostgreSQL | RabbitMQ | Vagrant | PM2**

---

## Table of Contents

1. Project Overview
2. Architecture
3. Prerequisites & Installation
4. Project File Structure
5. Environment Variables (.env)
6. Step 1 — Build the Inventory API
7. Step 2 — Build the Billing API
8. Step 3 — Build the API Gateway
9. Step 4 — Writing the Vagrantfile
10. Step 5 — Writing the Setup Scripts
11. Step 6 — Using PM2
12. Step 7 — OpenAPI / Swagger Documentation
13. Step 8 — Postman Testing
14. Audit Checklist & Verification
15. Troubleshooting

---

## 1. Project Overview

CRUD Master is a microservices project that simulates a movie streaming platform. It consists of three independent services, each running inside its own Vagrant virtual machine (VM). The services communicate over HTTP and via a RabbitMQ message queue, demonstrating key principles of distributed system design.

The three services are:

- **API Gateway** — the entry point for all client requests, running on its own `gateway-vm`.
- **Inventory API** — a full CRUD REST API for managing movies, running on `inventory-vm`.
- **Billing API** — a message-driven service that processes orders from a RabbitMQ queue, running on `billing-vm`.

> **Note:** The goal of this project is not only to build working APIs, but to understand how microservices communicate, how VMs are provisioned with Vagrant, and how to test resilience using message queues.

---

## 2. Architecture

The flow of data through the system:

- A **Client** sends HTTP requests to the **API Gateway**.
- The API Gateway routes `/api/movies/*` requests to the **Inventory API** via HTTP proxy.
- The API Gateway routes `/api/billing` POST requests by publishing a message to RabbitMQ's `billing_queue`.
- The **Billing API** consumes messages from `billing_queue` and writes orders to the PostgreSQL `orders` database.
- If the Billing API is offline, messages remain in the queue and are processed when the API restarts (queue durability / resilience).

**Communication protocols summary:**

| Route | Protocol | Destination |
|:---|:---|:---|
| `/api/movies/*` | HTTP Proxy | Inventory API (inventory-vm) |
| `/api/billing` POST | RabbitMQ (AMQP) | Billing API (billing-vm) |

---

## 3. Prerequisites & Installation

Before starting, ensure the following tools are installed on your **HOST machine** (your iMac, not inside a VM):

### 3.1 Required Tools

- **VirtualBox** (v6.1 or later) — Free VM hypervisor. Download from [virtualbox.org](https://virtualbox.org)
- **Vagrant** (v2.3 or later) — VM provisioning tool. Download from [vagrantup.com](https://vagrantup.com)
- **Postman** — API testing tool. Download from [postman.com](https://postman.com)
- **Python** (v3.10 or later) — For local development/testing before Vagrant
- **Git** — For version control

### 3.2 Installation Verification

Run these commands in your terminal to confirm installations:

```bash
virtualbox --help        # Should print VirtualBox CLI help
vagrant --version        # Should print: Vagrant 2.x.x
python3 --version        # Should print: Python 3.x.x
pip3 --version           # Should print pip version
git --version            # Should print git version
```

---

## 4. Project File Structure

This is the complete layout for the project. Create this directory and file structure from scratch:

```
.
├── README.md
├── config.yaml
├── .env
├── Vagrantfile
├── scripts/
│   ├── setup_inventory.sh
│   ├── setup_billing.sh
│   └── setup_gateway.sh
└── srcs/
    ├── api-gateway-app/
    │   ├── app/
    │   │   ├── __init__.py
    │   │   └── ...          // Other Python files (routes, proxy logic)
    │   ├── requirements.txt
    │   └── server.py
    ├── billing-app/
    │   ├── app/
    │   │   ├── __init__.py
    │   │   └── ...          // Other Python files (consumer, models, db config)
    │   ├── requirements.txt
    │   └── server.py
    └── inventory-app/
        ├── app/
        │   ├── __init__.py
        │   └── ...          // Other Python files (routes, models, controllers, db config)
        ├── requirements.txt
        └── server.py
```

> **Note:** Virtual environment folders (`venv/`, `__pycache__/`, `*.pyc`) are auto-generated. Do NOT commit them. Add them to your `.gitignore` file.

---

## 5. Environment Variables (.env)

The `.env` file lives at the root of the project and stores ALL credentials and configuration values. No credential should ever be hardcoded inside any Python source file. The Vagrantfile will read this file and inject the values into each VM as environment variables.

### 5.1 Creating the .env File

Create a file named `.env` at the root of your project directory:

```env
# Inventory Database (on inventory-vm)
INVENTORY_DB_NAME=movies
INVENTORY_DB_USER=inventory_user
INVENTORY_DB_PASSWORD=inventory_pass
INVENTORY_DB_HOST=localhost
INVENTORY_DB_PORT=5432

# Billing Database (on billing-vm)
BILLING_DB_NAME=orders
BILLING_DB_USER=billing_user
BILLING_DB_PASSWORD=billing_pass
BILLING_DB_HOST=localhost
BILLING_DB_PORT=5432

# RabbitMQ (on billing-vm)
RABBITMQ_USER=rabbitmq_user
RABBITMQ_PASSWORD=rabbitmq_pass
RABBITMQ_HOST=192.168.56.12
RABBITMQ_PORT=5672
RABBITMQ_QUEUE=billing_queue

# API Ports
INVENTORY_PORT=8080
BILLING_PORT=8081
GATEWAY_PORT=3000

# VM Static IPs
GATEWAY_IP=192.168.56.10
INVENTORY_IP=192.168.56.11
BILLING_IP=192.168.56.12
```

### 5.2 Why Include .env in the Repository?

Normally, `.env` files are added to `.gitignore` to prevent leaking credentials. However, for this project the subject explicitly requires the `.env` to be committed so the auditor can reproduce the setup. This is an exception for educational purposes only.

> **Important:** In real production projects, NEVER commit `.env` files to public repositories. Use secret managers like AWS Secrets Manager or HashiCorp Vault instead.

---

## 6. Step 1 — Build the Inventory API

The Inventory API is a standard RESTful CRUD API built with **Flask** and **SQLAlchemy ORM**, backed by a PostgreSQL database named `movies`. It runs on port **8080**.

### 6.1 Initialize the Project

Inside the `srcs/inventory-app/` directory, create a `requirements.txt` file:

```
flask
flask-sqlalchemy
psycopg2-binary
python-dotenv
```

Install dependencies:

```bash
pip3 install -r requirements.txt
```

- **flask** — Lightweight Python web framework
- **flask-sqlalchemy** — ORM for PostgreSQL (abstracts raw SQL)
- **psycopg2-binary** — PostgreSQL driver for Python
- **python-dotenv** — Loads environment variables from `.env` into `os.environ`

### 6.2 Configure the Database Connection (app/config/db.py or inside `__init__.py`)

This file creates and exports a SQLAlchemy instance. It reads all credentials from environment variables — never hardcode them. Build the database URI from env vars:

```python
import os
DATABASE_URI = (
    f"postgresql://{os.environ['INVENTORY_DB_USER']}:"
    f"{os.environ['INVENTORY_DB_PASSWORD']}@"
    f"{os.environ['INVENTORY_DB_HOST']}:"
    f"{os.environ['INVENTORY_DB_PORT']}/"
    f"{os.environ['INVENTORY_DB_NAME']}"
)
```

### 6.3 Define the Movie Model

Use SQLAlchemy's `db.Model` to create the `movies` table schema. The columns must be:

- `id` — Integer, auto-increment primary key
- `title` — String, cannot be null
- `description` — Text, can be null

Call `db.create_all()` inside the app context on startup to auto-create the table if it does not exist.

### 6.4 Write the Controller / Route Logic

Using Flask routes and SQLAlchemy, implement:

- `Movie.query.all()` — returns all movies, supports optional `?title=` filter
- `Movie.query.get(id)` — returns a single movie by primary key
- `db.session.add(movie)` — creates a new movie row from request JSON
- `db.session.commit()` — saves changes
- `db.session.delete(movie)` — deletes a single movie
- `Movie.query.delete()` — deletes all movies

Return appropriate HTTP status codes: `200` for success, `404` if movie not found, `500` for server errors. Always respond with JSON.

### 6.5 Define Routes

Map HTTP methods to functions in your Flask app:

| Method | Endpoint | Description |
|:---|:---|:---|
| GET | `/api/movies` | Get all movies (supports `?title=` query) |
| POST | `/api/movies` | Create a new movie |
| DELETE | `/api/movies` | Delete all movies |
| GET | `/api/movies/<id>` | Get one movie by ID |
| PUT | `/api/movies/<id>` | Update one movie by ID |
| DELETE | `/api/movies/<id>` | Delete one movie by ID |

### 6.6 Write the Server Entry Point (server.py)

`server.py` is the main entry point. It should:

1. Load environment variables using `python-dotenv` as the very first step so `os.environ` is populated before anything else is imported.
2. Import Flask and create an app instance.
3. Configure `app.config['SQLALCHEMY_DATABASE_URI']` from env vars.
4. Initialize SQLAlchemy with the app.
5. Register your routes/blueprints.
6. Call `db.create_all()` inside `app.app_context()` to sync models.
7. Call `app.run(host='0.0.0.0', port=int(os.environ['INVENTORY_PORT']))` to start the server.

### 6.7 Local Testing (Before Vagrant)

To verify the API works before setting up VMs, you need a local PostgreSQL instance:

```bash
psql -U postgres
CREATE DATABASE movies;
CREATE USER inventory_user WITH PASSWORD 'inventory_pass';
GRANT ALL PRIVILEGES ON DATABASE movies TO inventory_user;
```

Then start the server locally:

```bash
python3 server.py
```

Test with curl or Postman: POST to `http://localhost:8080/api/movies` with a JSON body containing `title` and `description`.

---

## 7. Step 2 — Build the Billing API

The Billing API does **NOT** expose any HTTP endpoints. Instead, it listens on a RabbitMQ queue called `billing_queue`. When a message arrives, it parses the JSON, creates a database record in the `orders` PostgreSQL database, and acknowledges the message. A key requirement is **resilience**: messages must persist in the queue when the API is offline and be processed when it restarts.

### 7.1 Initialize the Project

Inside `srcs/billing-app/`, create `requirements.txt`:

```
pika
flask-sqlalchemy
psycopg2-binary
python-dotenv
sqlalchemy
```

Install:

```bash
pip3 install -r requirements.txt
```

- **pika** — Python AMQP client for RabbitMQ (equivalent of amqplib in Node.js)

### 7.2 Configure the Database (app config)

Same pattern as Inventory API, but using `BILLING_DB_NAME`, `BILLING_DB_USER`, `BILLING_DB_PASSWORD` from `os.environ`.

### 7.3 Define the Order Model

Create the `orders` table with the following columns:

- `id` — Integer, auto-increment primary key
- `user_id` — String, cannot be null
- `number_of_items` — String, cannot be null
- `total_amount` — String, cannot be null

### 7.4 Write the Consumer Logic

This is the core of the Billing API. Using **pika**, the consumer function must:

1. Connect to RabbitMQ using `pika.BlockingConnection(pika.ConnectionParameters(...))` with credentials from env vars.
2. Create a channel using `connection.channel()`.
3. Declare the queue as durable: `channel.queue_declare(queue='billing_queue', durable=True)`. The `durable=True` flag ensures the queue survives a RabbitMQ restart.
4. Set `channel.basic_qos(prefetch_count=1)` — tells RabbitMQ to deliver one message at a time.
5. Call `channel.basic_consume(queue='billing_queue', on_message_callback=callback)`.
6. Inside the callback, parse `body.decode()` using `json.loads()` to extract `user_id`, `number_of_items`, `total_amount`.
7. Use SQLAlchemy to create a new order record in the database.
8. After successful database write, call `ch.basic_ack(delivery_tag=method.delivery_tag)` to acknowledge the message.

> **Important:** Always `ack` AFTER a successful database write. If you ack before and the write fails, the message is lost forever.

### 7.5 Write the Server Entry Point (server.py)

The `server.py` for the Billing API is simpler. It should:

1. Load `.env` with `python-dotenv` first.
2. Create the SQLAlchemy models / tables.
3. Call the RabbitMQ consumer function to start listening: `channel.start_consuming()`.

> **Note:** There is no `app.run()` call in the Billing API since it does not serve HTTP requests. It simply connects to RabbitMQ and waits for messages.

---

## 8. Step 3 — Build the API Gateway

The API Gateway is the single entry point for all external traffic. It **proxies** Inventory requests over HTTP and **publishes** Billing requests to RabbitMQ. It runs on port **3000**.

### 8.1 Initialize the Project

Inside `srcs/api-gateway-app/`, create `requirements.txt`:

```
flask
requests
pika
python-dotenv
```

- **requests** — Python HTTP library to forward/proxy requests to the Inventory API
- **pika** — Same AMQP client used in Billing API

### 8.2 Set Up the HTTP Proxy

For all `/api/movies/*` routes, use Python's `requests` library to forward the incoming request to the Inventory API:

```python
import requests, os

INVENTORY_URL = f"http://{os.environ['INVENTORY_IP']}:{os.environ['INVENTORY_PORT']}"

@app.route('/api/movies', methods=['GET', 'POST', 'DELETE'])
def proxy_movies():
    url = f"{INVENTORY_URL}/api/movies"
    resp = requests.request(
        method=request.method,
        url=url,
        json=request.get_json(),
        params=request.args
    )
    return resp.content, resp.status_code, resp.headers.items()
```

Add an error handler to return `502` if the Inventory API is unreachable.

### 8.3 Set Up RabbitMQ Publisher

The route `POST /api/billing` must:

1. Connect to RabbitMQ at the billing-vm's IP using `pika`.
2. Declare `billing_queue` with `durable=True`.
3. Use `channel.basic_publish()` with `properties=pika.BasicProperties(delivery_mode=2)` — the `delivery_mode=2` flag makes messages persistent (survives RabbitMQ restart).
4. Return HTTP `200` to the client immediately after publishing. You do not wait for the Billing API to process it. This is what allows the gateway to return `200` even when `billing-app` is stopped.

### 8.4 Write the Server Entry Point (server.py)

The gateway `server.py` should:

1. Load `.env` with `python-dotenv`.
2. Create a Flask app.
3. Register all routes (proxy routes for `/api/movies` and publisher route for `/api/billing`).
4. Start listening: `app.run(host='0.0.0.0', port=int(os.environ['GATEWAY_PORT']))`.

---

## 9. Step 4 — Writing the Vagrantfile

The `Vagrantfile` is a Ruby-syntax configuration file that defines all three VMs. It lives at the root of the project. Vagrant reads it when you run `vagrant up`.

### 9.1 Loading Environment Variables

At the top of the Vagrantfile (before the `Vagrant.configure` block), load the `.env` file using Ruby's built-in file reading. Parse each line that is not a comment, split on `=`, and store key-value pairs in a Ruby hash. Then inject them into the Vagrant environment:

```ruby
env = {}
File.foreach('.env') do |line|
  next if line.strip.start_with?('#') || line.strip.empty?
  key, value = line.strip.split('=', 2)
  env[key] = value
end
```

### 9.2 VM Definitions

Define each VM inside a `Vagrant.configure('2') do |config|` block using `config.vm.define`. Each VM needs:

- A unique name (`gateway-vm`, `inventory-vm`, `billing-vm`)
- A base box — use `ubuntu/focal64` (Ubuntu 20.04 LTS)
- A static private IP from your `.env` (e.g., `192.168.56.10`, `.11`, `.12`)
- A synced folder — sync `srcs/` from the host into the VM: `vm.synced_folder './srcs', '/home/vagrant/srcs'`
- A shell provisioner pointing to the relevant setup script

### 9.3 Passing Environment Variables to Provisioners

In the provision block, pass the relevant environment variables as a hash to the `env` option:

```ruby
config.vm.define "inventory-vm" do |inv|
  inv.vm.box = "ubuntu/focal64"
  inv.vm.network "private_network", ip: env['INVENTORY_IP']
  inv.vm.synced_folder "./srcs", "/home/vagrant/srcs"
  inv.vm.provision "shell", path: "scripts/setup_inventory.sh", env: {
    "INVENTORY_DB_NAME"     => env['INVENTORY_DB_NAME'],
    "INVENTORY_DB_USER"     => env['INVENTORY_DB_USER'],
    "INVENTORY_DB_PASSWORD" => env['INVENTORY_DB_PASSWORD'],
    "INVENTORY_PORT"        => env['INVENTORY_PORT']
  }
end
```

### 9.4 Key Vagrant Commands

```bash
vagrant up              # Boot and provision all 3 VMs
vagrant status          # Show running status of all VMs
vagrant ssh gateway-vm  # SSH into the gateway VM
vagrant ssh inventory-vm # SSH into the inventory VM
vagrant ssh billing-vm  # SSH into the billing VM
vagrant halt            # Gracefully shut down all VMs
vagrant destroy -f      # Delete all VMs (destructive!)
vagrant provision       # Re-run provisioning scripts
vagrant reload          # Restart VMs and re-apply config
```

> **Note:** The first `vagrant up` will download the `ubuntu/focal64` box (~500MB). This only happens once and is cached locally for future use.

---

## 10. Step 5 — Writing the Setup Scripts

Each VM has a corresponding bash setup script in the `scripts/` directory. These scripts run during `vagrant up` provisioning and install all required software, set up databases, configure services, and start the Python application with PM2.

### 10.1 scripts/setup_inventory.sh

This script runs on `inventory-vm`. Steps in order:

1. Update apt package index: `apt-get update -y`
2. Install Python 3 and pip: `apt-get install -y python3 python3-pip python3-venv`
3. Install PostgreSQL: `apt-get install -y postgresql postgresql-contrib`
4. Start and enable PostgreSQL: `systemctl start postgresql && systemctl enable postgresql`
5. Create the PostgreSQL user and database:
   ```bash
   sudo -u postgres psql -c "CREATE USER $INVENTORY_DB_USER WITH PASSWORD '$INVENTORY_DB_PASSWORD';"
   sudo -u postgres psql -c "CREATE DATABASE $INVENTORY_DB_NAME;"
   sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $INVENTORY_DB_NAME TO $INVENTORY_DB_USER;"
   ```
6. Install PM2 globally (requires Node.js for PM2 only): `apt-get install -y nodejs npm && npm install -g pm2`
7. Navigate to the synced app directory: `cd /home/vagrant/srcs/inventory-app`
8. Install Python dependencies: `pip3 install -r requirements.txt`
9. Write environment variables to a `.env` file inside the app directory using `echo` statements so `python-dotenv` can load them.
10. Start the application with PM2: `pm2 start server.py --name inventory_app --interpreter python3`
11. Save the PM2 process list and configure startup: `pm2 save && pm2 startup`

### 10.2 scripts/setup_billing.sh

This script runs on `billing-vm`. In addition to Python, PostgreSQL, and PM2, it must also install and configure RabbitMQ:

1. Update packages and install Python 3 (same as above)
2. Install PostgreSQL and create the `orders` database and `billing_user`
3. Install RabbitMQ: `apt-get install -y rabbitmq-server`
4. Start and enable RabbitMQ: `systemctl start rabbitmq-server && systemctl enable rabbitmq-server`
5. Create a RabbitMQ user:
   ```bash
   rabbitmqctl add_user $RABBITMQ_USER $RABBITMQ_PASSWORD
   rabbitmqctl set_user_tags $RABBITMQ_USER administrator
   rabbitmqctl set_permissions -p / $RABBITMQ_USER '.*' '.*' '.*'
   rabbitmqctl delete_user guest
   ```
6. Install PM2 globally
7. Navigate to `/home/vagrant/srcs/billing-app`, run `pip3 install -r requirements.txt`
8. Write the `.env` file and start with PM2: `pm2 start server.py --name billing_app --interpreter python3`
9. Save PM2 process list

> **Important:** RabbitMQ listens on port `5672` by default. The billing-vm's static IP (e.g., `192.168.56.12`) must match `RABBITMQ_HOST` in your `.env` file so the gateway can reach it.

### 10.3 scripts/setup_gateway.sh

This script runs on `gateway-vm`. It is the simplest of the three:

1. Install Python 3 and pip
2. Install PM2 globally (requires Node.js for PM2)
3. Navigate to `/home/vagrant/srcs/api-gateway-app`
4. Run `pip3 install -r requirements.txt`
5. Write the `.env` file with `INVENTORY_IP`, `INVENTORY_PORT`, `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_QUEUE`, `GATEWAY_PORT`
6. Start with PM2: `pm2 start server.py --name api_gateway --interpreter python3`
7. Save PM2 process list

> **Note:** The gateway does NOT need PostgreSQL. It only needs Python, the app dependencies, and access to the other VMs over the private network.

---

## 11. Step 6 — Using PM2

PM2 (Process Manager 2) is a production-grade process manager. It keeps your apps alive, restarts them on crashes, and provides logging and monitoring. It is critical for this project because it allows you to start and stop individual services during audit testing.

> **Note:** PM2 is a Node.js tool but works perfectly as a process manager for Python scripts by using the `--interpreter python3` flag.

### 11.1 Core PM2 Commands

```bash
sudo pm2 list                          # Show all managed apps and their status
sudo pm2 start server.py --name <name> --interpreter python3  # Start a Python app
sudo pm2 stop <app_name>               # Stop a running app
sudo pm2 restart <app_name>            # Restart a running app
sudo pm2 delete <app_name>             # Remove app from PM2 list
sudo pm2 logs <app_name>               # Stream live logs
sudo pm2 logs <app_name> --lines 50    # Show last 50 log lines
sudo pm2 monit                         # Interactive monitoring dashboard
```

### 11.2 How PM2 Enables the Resilience Test

The audit requires demonstrating that messages sent to the billing queue while `billing_app` is stopped are processed when it restarts. Exact test sequence:

1. SSH into billing-vm: `vagrant ssh billing-vm`
2. Stop the billing app: `sudo pm2 stop billing_app`
3. Confirm it is stopped: `sudo pm2 list` (status should show `stopped`)
4. From Postman, POST to `/api/billing` — you should get `200 OK` from the gateway even though `billing_app` is down
5. Verify the message is NOT yet in the orders database: `sudo -i -u postgres psql -c 'SELECT * FROM orders;' orders`
6. Restart the app: `sudo pm2 start billing_app`
7. Check the database again — the order should now appear (RabbitMQ delivered the queued message)

> **Note:** This works because RabbitMQ persists durable messages on disk. When `billing_app` reconnects and calls `channel.start_consuming()`, RabbitMQ delivers all unacknowledged messages.

---

## 12. Step 7 — OpenAPI / Swagger Documentation

Every professional API requires documentation. You must create an OpenAPI 3.0 specification file that documents all API Gateway endpoints.

### 12.1 What to Document

Your OpenAPI spec must include descriptions for all of the following:

- `GET /api/movies` — List all movies; document the optional `?title` query parameter
- `POST /api/movies` — Create a movie; document the request body schema with `title` and `description`
- `DELETE /api/movies` — Delete all movies
- `GET /api/movies/{id}` — Get movie by ID; document the path parameter
- `PUT /api/movies/{id}` — Update movie; document path parameter and request body
- `DELETE /api/movies/{id}` — Delete movie by ID
- `POST /api/billing` — Create an order; document the request body with `user_id`, `number_of_items`, `total_amount`

### 12.2 Recommended Approach: SwaggerHub

1. Create a free account at [swaggerhub.com](https://swaggerhub.com)
2. Click 'Create New API' and select OpenAPI 3.0
3. Use the editor to write your spec — it validates in real time
4. Export the spec as `openapi.yaml` and save it to the root of your project

### 12.3 Minimum Required YAML Structure

```yaml
openapi: 3.0.0
info:
  title: CRUD Master API Gateway
  version: 1.0.0
  description: API Gateway for movie inventory and billing microservices
paths:
  /api/movies:
    get:
      summary: Retrieve all movies
      # ... parameters, responses
    post:
      summary: Create a new movie
      # ... requestBody, responses
  # ... remaining endpoints
```

---

## 13. Step 8 — Postman Testing

Postman is used to test all API endpoints manually and to create an exportable collection that auditors can import and run.

### 13.1 Setting Up the Postman Collection

1. Open Postman and click 'New Collection'. Name it `CRUD Master`.
2. Add a collection-level variable named `GATEWAY_URL` with value `http://192.168.56.10:3000`.
3. Create requests for each endpoint inside the collection.

### 13.2 Required Requests to Create

| Method | Endpoint | Description |
|:---|:---|:---|
| POST | `/api/movies` | Body: `{title, description}`. Expected: 200 + created movie |
| GET | `/api/movies` | No body. Expected: 200 + array of all movies |
| GET | `/api/movies?title=...` | Query param filter. Expected: 200 + filtered array |
| GET | `/api/movies/:id` | Path param. Expected: 200 + single movie |
| PUT | `/api/movies/:id` | Body: `{title, description}`. Expected: 200 + updated movie |
| DELETE | `/api/movies/:id` | Path param. Expected: 200 + success message |
| DELETE | `/api/movies` | No body. Expected: 200 + success message |
| POST | `/api/billing` | Body: `{user_id, number_of_items, total_amount}`. Expected: 200 |

### 13.3 Exporting the Collection

1. Right-click the collection in Postman's sidebar and select 'Export'.
2. Choose 'Collection v2.1' format.
3. Save the exported JSON file inside your project repository (e.g., at the root or in a `postman/` directory).
4. Commit the file to git.

---

## 14. Audit Checklist & Verification

### 14.1 VM Configuration Checks

Run these commands from the project root on the host machine:

```bash
vagrant up      # Should boot all 3 VMs without errors
vagrant status  # Should show 3 VMs all in 'running' state
cat .env        # Should show all credentials — no empty values
```

- Confirm `gateway-vm`, `inventory-vm`, and `billing-vm` all appear as `running`.
- Confirm `.env` contains credentials for both databases, RabbitMQ, ports, and IPs.
- Verify no credentials are hardcoded in Python files: `grep -r 'password' srcs/` should return no hardcoded strings.

### 14.2 Inventory API Endpoints Verification

With Postman, using the gateway IP and port (`http://192.168.56.10:3000`):

1. POST `/api/movies` with `{"title": "A new movie", "description": "Very short description"}` — expect 200.
2. GET `/api/movies` — expect 200 and the newly created movie in the response array.
3. Import the Postman collection file. Run all requests. All should return expected responses.

### 14.3 Inventory Database Verification

```bash
vagrant ssh inventory-vm
sudo -i -u postgres
psql
\l               # movies database should appear in list
\c movies
TABLE movies;    # Should show rows matching your Postman requests
```

### 14.4 Billing API Endpoints Verification

POST `/api/billing` with `{"user_id": "20", "number_of_items": "99", "total_amount": "250"}` — expect 200.

```bash
vagrant ssh billing-vm
sudo pm2 stop billing_app
sudo pm2 list   # billing_app should show status: stopped
```

Then POST `/api/billing` with `{"user_id": "22", "number_of_items": "10", "total_amount": "50"}` — still expect 200 from gateway.

### 14.5 Billing Database Verification

```bash
vagrant ssh billing-vm
sudo -i -u postgres
psql
\l               # orders database should appear
\c orders
TABLE orders;    # user_id=20 should be present, user_id=22 should NOT yet
```

### 14.6 Queue Resilience Verification

```bash
sudo pm2 start billing_app   # Restart the billing service
# Wait 3-5 seconds
TABLE orders;                # user_id=22 should NOW appear
```

This confirms that RabbitMQ held the message while `billing_app` was down and delivered it upon reconnect.

---

## 15. Troubleshooting

### VMs not starting or timing out

- Check VirtualBox is installed and running by opening the VirtualBox GUI.
- Run `vagrant up --debug 2>&1 | tee vagrant_debug.log` to capture the full debug log.
- Try `vagrant destroy -f` and `vagrant up` to start fresh.

### PostgreSQL connection errors

- Ensure the PostgreSQL service is running inside the VM: `sudo systemctl status postgresql`
- Check the user and database were created: `sudo -i -u postgres psql -c '\l'`
- Verify the password in `.env` exactly matches what was used to create the DB user.

### RabbitMQ connection errors from Gateway

- The gateway VM must be able to reach billing-vm on port 5672. Test with:
  ```bash
  nc -zv 192.168.56.12 5672
  ```
  (run this from inside gateway-vm)
- Ensure the RabbitMQ user credentials in `.env` match what was configured in the setup script.
- Check RabbitMQ is running on billing-vm: `sudo systemctl status rabbitmq-server`

### Messages not processing after billing_app restart

- Ensure the queue was declared with `durable=True` in BOTH the gateway publisher and the billing consumer.
- Ensure messages were sent with `delivery_mode=2` in `basic_publish()`.
- Check PM2 logs for errors: `sudo pm2 logs billing_app`

### Postman returns Connection Refused

- Confirm the correct gateway VM IP is being used (check `vagrant status` and `vm.network` in Vagrantfile).
- Verify the gateway app is running: `vagrant ssh gateway-vm`, then `sudo pm2 list`.
- Ensure port 3000 is not blocked: `sudo ufw status`

### Python app not starting with PM2

- Verify Python 3 is installed: `python3 --version`
- Check PM2 was started with the `--interpreter python3` flag.
- Check logs: `sudo pm2 logs api_gateway` or `sudo pm2 logs inventory_app`

---

*CRUD Master — Complete Project Guide*
*Python | Flask | SQLAlchemy | PostgreSQL | RabbitMQ | Vagrant | PM2 | Postman | OpenAPI*
