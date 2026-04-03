# CRUD Master - Microservices Architecture

A production-ready microservices project demonstrating distributed system design principles with Python, Flask, PostgreSQL, RabbitMQ, and Vagrant.

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Services Overview](#services-overview)
- [API Endpoints](#api-endpoints)
- [Database Setup](#database-setup)
- [Testing with Postman](#testing-with-postman)
- [Key Features](#key-features)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Project Overview

**CRUD Master** is a microservices-based movie inventory and billing system that demonstrates:

- **Distributed Architecture**: Three independent services running on separate VMs
- **Reverse Proxy Pattern**: API Gateway acting as reverse proxy for unified client entry point
- **HTTP Proxy Pattern**: API Gateway routing requests via HTTP proxy to backend services
- **Message Queue Pattern**: Asynchronous order processing via RabbitMQ
- **Database Persistence**: PostgreSQL for data durability
- **Service Resilience**: Queue durability and eventual consistency
- **Infrastructure as Code**: Vagrant for reproducible VM provisioning

### Stack

| Component              | Technology           |
| ---------------------- | -------------------- |
| **VMs & Provisioning** | VirtualBox + Vagrant |
| **Runtime**            | Python 3.10+         |
| **Web Framework**      | Flask                |
| **Databases**          | PostgreSQL 16        |
| **Message Queue**      | RabbitMQ 4.x         |
| **Process Manager**    | PM2                  |
| **Testing**            | Postman              |
| **Documentation**      | OpenAPI/Swagger      |

---

## 🏗️ Architecture

```
                          ┌─────────────────────────────────┐
                          │        Client Machine           │
                          │    (Postman / Browser)          │
                          └──────────────┬────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
        ┌───────────▼──────────┐  ┌─────▼─────────┐  ┌──────▼──────────┐
        │    GATEWAY-VM        │  │ INVENTORY-VM  │  │   BILLING-VM    │
        │   Port: 3000         │  │ Port: 8080    │  │   Port: 8081    │
        ├──────────────────────┤  ├───────────────┤  ├─────────────────┤
        │  API Gateway         │  │ Inventory API │  │  Billing API    │
        │  (Flask)             │  │  (Flask)      │  │   Consumer      │
        │                      │  │               │  │  (RabbitMQ)     │
        │ Routes:              │  │ Routes:       │  │                 │
        │ • /api/movies/*      │  │ • /api/movies │  │ Consumes:       │
        │   (HTTP proxy)       │  │   CRUD        │  │ billing_queue   │
        │ • /api/billing       │  │               │  │                 │
        │   (RabbitMQ pub)     │  │ Database:     │  │ Database:       │
        │ • /health            │  │ movies DB     │  │ orders DB       │
        │                      │  │               │  │                 │
        └──────────┬───────────┘  └────────┬──────┘  └────────┬────────┘
                   │                       │                  │
                   │        HTTP           │    RabbitMQ      │
                   │        Proxy          │    Publisher     │
                   │                       │                  │
                   │         ┌─────────────┘                  │
                   │         │                                │
                   │         ▼                                │
        ┌──────────┴──────────────────┐    ┌──────────────────▼──────┐
        │   PostgreSQL Databases      │    │   RabbitMQ Queue        │
        ├─────────────────────────────┤    ├─────────────────────────┤
        │ • movies DB (Inventory)     │    │ • billing_queue         │
        │ • orders DB (Billing)       │    │   (Durable messages)    │
        │                             │    │                         │
        │ Users:                      │    │ Queue Features:         │
        │ • inventory_user            │    │ • Persistent            │
        │ • billing_user              │    │ • Async processing      │
        │ • postgres (admin)          │    │ • Loss recovery         │
        └─────────────────────────────┘    └─────────────────────────┘
```

### Reverse Proxy Pattern

The **API Gateway** acts as a **reverse proxy**, providing a single point of entry for all clients:

```
Clients (Multiple)          API Gateway              Backend Services
      │                          │                           │
      ├─► Single IP:Port ────►  │ (Reverse Proxy)           │
      │   192.168.56.10:3000    │                           │
      │                         ├─► /api/movies/* ─────────► Inventory API (8080)
      │                         │                           │
      │                         ├─► /api/billing ─────────► RabbitMQ Queue
      │                         │                           │
      └──────────────────────┬──┘                           │
                             │
                      Response routed
                      back to client
```

**Benefits of Reverse Proxy:**

- **Single Entry Point**: Clients only know Gateway URL (192.168.56.10:3000)
- **Service Abstraction**: Hide internal service IPs from clients
- **Easy Maintenance**: Change backend services without affecting clients
- **Load Balancing**: Route to multiple backend instances if needed
- **Security**: Hide internal architecture topology
- **Centralized Control**: Logging, rate limiting, authentication in one place

---

### Data Flow

**CRUD Operations (Movies):**

```
Client → API Gateway (3000) [Reverse Proxy]
       → Inventory API (8080) [HTTP Proxy Forward]
       → PostgreSQL movies DB
       ↓ (Response back through same path)
```

**Billing Operations (Orders):**

```
Client → API Gateway (3000)
       → RabbitMQ Queue
       ↓ (Asynchronously)
Billing API Consumer reads queue
       → PostgreSQL orders DB
       ↓ (Message durability - survives crashes)
```

---

## 📦 Prerequisites

### System Requirements

- **Processor**: Intel or ARM (M1/M2/M3 Mac compatible)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 20GB free space
- **OS**: macOS, Linux, or Windows (with WSL2)

### Required Tools

Verify installation before starting:

**VirtualBox** (v6.1+)

```bash
virtualbox --version
```

**Vagrant** (v2.3+)

```bash
vagrant --version
```

**Postman** (Latest)

- Download from [postman.com](https://www.postman.com/downloads/)
- Or use web version at [web.postman.co](https://web.postman.co)

**Python** (v3.10+)

```bash
python3 --version
```

**Git** (for version control)

```bash
git --version
```

---

## 🚀 Quick Start

### Step 1: Clone and Navigate

```bash
cd /Users/saddam.hussain/Desktop/CRUD-MASTER
```

### Step 2: Start All VMs

```bash
vagrant up
```

This will:

- Create 3 VMs (gateway-vm, inventory-vm, billing-vm)
- Install all dependencies
- Set up PostgreSQL databases
- Start all services

**Expected time**: 3-5 minutes

### Step 3: Verify VMs Are Running

```bash
vagrant status
```

Expected output:

```
gateway-vm                   running (virtualbox)
inventory-vm                 running (virtualbox)
billing-vm                   running (virtualbox)
```

### Step 4: Start Services

```bash
./start_services.sh
```

This starts:

- API Gateway on port 3000
- Inventory API on port 8080
- Billing API (RabbitMQ consumer)

### Step 5: Import Postman Collection

1. Open Postman
2. Click **File** → **Import**
3. Select `CRUD_Master.postman_collection.json`
4. Run collection: Click ⏶ **Run Collection**

### Step 6: Test Endpoints

- **GET /api/movies**: Retrieve all movies
- **POST /api/movies**: Create a new movie
- **POST /api/billing**: Create an order

---

## 📂 Project Structure

```
CRUD-MASTER/
│
├── README.md                           # Main documentation (this file)
├── CRUD_Master_README.md               # Detailed setup guide
├── AUDIT_VERIFICATION_CHECKLIST.md     # Audit requirements verification
│
├── Vagrantfile                         # VM provisioning configuration
├── .env                                # Environment variables (credentials)
├── .gitignore                          # Git ignore rules
│
├── srcs/                               # Application source code
│   ├── api-gateway-app/                # API Gateway service
│   │   ├── server.py                   # Entry point (Flask app)
│   │   ├── requirements.txt            # Python dependencies
│   │   └── app/__init__.py             # Route definitions
│   │
│   ├── inventory-app/                  # Inventory API service
│   │   ├── server.py                   # Entry point
│   │   ├── requirements.txt            # Dependencies
│   │   └── app/
│   │       ├── __init__.py             # App factory
│   │       ├── routes.py               # CRUD endpoints
│   │       ├── models.py               # SQLAlchemy models
│   │       └── db.py                   # Database setup
│   │
│   └── billing-app/                    # Billing API service
│       ├── server.py                   # Entry point (RabbitMQ consumer)
│       ├── requirements.txt            # Dependencies
│       └── app/
│           ├── __init__.py             # App factory
│           ├── consumer.py             # RabbitMQ consumer
│           ├── models.py               # SQLAlchemy models
│           └── db.py                   # Database setup
│
├── scripts/                            # Provisioning scripts
│   ├── setup_inventory.sh              # Inventory VM setup
│   ├── setup_billing.sh                # Billing VM setup
│   └── setup_gateway.sh                # Gateway VM setup
│
├── logs/                               # Service logs
│   ├── inventory-api.log
│   ├── billing-api.log
│   └── gateway.log
│
├── CRUD_Master.postman_collection.json # Postman collection (all endpoints)
├── openapi.yaml                        # API specification
├── health_check_report.txt             # Health check results
├── postman-results.json                # Test execution results
│
└── start_services.sh                   # Script to start all services
```

---

## 🔧 Services Overview

### 1. API Gateway (Gateway-VM)

**Port**: 3000  
**Purpose**: Reverse proxy - single entry point for all client requests  
**Technology**: Python + Flask  
**Pattern**: Reverse Proxy + HTTP Proxy

#### Features:

- **Reverse Proxy Pattern**: Receives all client requests at single URL (192.168.56.10:3000)
- **HTTP Proxy Implementation**: Forwards `/api/movies/*` requests to Inventory API backend
- **Service Abstraction**: Clients don't know about internal Inventory API address
- **Message Publisher**: Routes `/api/billing` to RabbitMQ for async processing
- **Health check endpoint**: `/health` for monitoring
- **Connection pooling and timeouts**: Reliable backend communication
- **Request forwarding**: Preserves HTTP methods, headers, query parameters, and body

#### Configuration:

```env
GATEWAY_IP=192.168.56.10
GATEWAY_PORT=3000
INVENTORY_IP=192.168.56.11
INVENTORY_PORT=8080
```

---

### 2. Inventory API (Inventory-VM)

**Port**: 8080  
**Purpose**: Movie CRUD operations  
**Database**: PostgreSQL (movies DB)

#### Endpoints:

| Method | Endpoint              | Purpose           |
| ------ | --------------------- | ----------------- |
| POST   | `/api/movies`         | Create movie      |
| GET    | `/api/movies`         | List all movies   |
| GET    | `/api/movies?title=X` | Filter by title   |
| GET    | `/api/movies/{id}`    | Get single movie  |
| PUT    | `/api/movies/{id}`    | Update movie      |
| DELETE | `/api/movies/{id}`    | Delete movie      |
| DELETE | `/api/movies`         | Delete all movies |

#### Data Model:

```python
Movie:
  - id (auto-generated)
  - title (string)
  - description (text)
  - genre (string)
  - release_year (integer)
  - rating (float)
  - duration (integer)
  - available_copies (integer)
  - created_at (timestamp)
  - updated_at (timestamp)
```

---

### 3. Billing API (Billing-VM)

**Purpose**: Async order processing  
**Transport**: RabbitMQ message queue  
**Database**: PostgreSQL (orders DB)

#### Features:

- Consumes messages from `billing_queue`
- Processes orders asynchronously
- Durable queue (survives crashes)
- Automatic message replay on restart

#### Endpoint:

| Method | Endpoint       | Purpose                   |
| ------ | -------------- | ------------------------- |
| POST   | `/api/billing` | Queue order (via Gateway) |

#### Data Model:

```python
Order:
  - id (auto-generated)
  - user_id (string)
  - number_of_items (integer)
  - total_amount (decimal)
  - created_at (timestamp)
```

#### RabbitMQ Configuration:

```env
RABBITMQ_HOST=192.168.56.30
RABBITMQ_PORT=5672
RABBITMQ_USER=billing_rmq
RABBITMQ_PASSWORD=billing_rmq_pass
RABBITMQ_QUEUE=billing_queue
```

---

## 🔗 API Endpoints

### Base URL

```
http://192.168.56.10:3000
```

### Movie Management (Full CRUD)

#### Create Movie

```http
POST /api/movies
Content-Type: application/json

{
  "title": "Inception",
  "description": "A mind-bending thriller",
  "genre": "Sci-Fi",
  "release_year": 2010,
  "rating": 8.8,
  "duration": 148,
  "available_copies": 5
}
```

**Response** (200 OK):

```json
{
  "success": true,
  "message": "Movie created successfully",
  "movie": {
    "id": 1,
    "title": "Inception",
    "created_at": "2024-04-01T10:30:00",
    "updated_at": "2024-04-01T10:30:00"
  }
}
```

#### Get All Movies

```http
GET /api/movies
```

**Response** (200 OK):

```json
{
  "success": true,
  "count": 5,
  "movies": [...]
}
```

#### Filter Movies by Title

```http
GET /api/movies?title=inception
```

#### Get Single Movie

```http
GET /api/movies/1
```

#### Update Movie

```http
PUT /api/movies/1
Content-Type: application/json

{
  "rating": 9.0,
  "available_copies": 3
}
```

#### Delete Movie

```http
DELETE /api/movies/1
```

#### Delete All Movies

```http
DELETE /api/movies
```

### Order Management (Async)

#### Create Order

```http
POST /api/billing
Content-Type: application/json

{
  "user_id": "user123",
  "number_of_items": "5",
  "total_amount": "99.99"
}
```

**Response** (200 OK - Immediate):

```json
{
  "message": "Order queued successfully for processing",
  "order": {
    "user_id": "user123",
    "number_of_items": "5",
    "total_amount": "99.99"
  }
}
```

**Note**: Returns 200 immediately (async). Order processed by Billing API consumer in background.

### Health Check

#### Gateway Health

```http
GET /health
```

**Response** (200 OK):

```json
{
  "status": "healthy",
  "service": "API Gateway"
}
```

---

## 🗄️ Database Setup

### PostgreSQL Structure

Two separate databases on the billing-vm:

#### 1. Movies Database (Inventory-VM)

**Name**: movies  
**User**: inventory_user  
**Port**: 5432

**Access**:

```bash
vagrant ssh inventory-vm
sudo -i -u postgres
psql -d movies
```

**Tables**:

- `movies` - Movie inventory
- `logs` (if audit logs enabled)

---

#### 2. Orders Database (Billing-VM)

**Name**: orders  
**User**: billing_user  
**Port**: 5432

**Access**:

```bash
vagrant ssh billing-vm
sudo -i -u postgres
psql -d orders
```

**Tables**:

- `orders` - Order records
- `order_items` (if detailed line items stored)

---

### Verify Databases

**List all databases**:

```bash
vagrant ssh inventory-vm
sudo -i -u postgres
psql
\l
```

**View database contents**:

```bash
\c movies
SELECT * FROM movies;

\c orders
SELECT * FROM orders;
```

---

## 🧪 Testing with Postman

### Import Collection

1. **Open Postman**
2. **File** → **Import** → Select `CRUD_Master.postman_collection.json`
3. Collection appears in left sidebar

### Collection Structure

```
📦 CRUD Master - Audit Validation Suite
├── 📂 Movies
│   ├── POST /api/movies - create movie
│   ├── GET /api/movies - all movies
│   ├── GET /api/movies?title=X - filter
│   ├── GET /api/movies/{id} - get one
│   ├── PUT /api/movies/{id} - update
│   ├── DELETE /api/movies/{id} - delete one
│   └── DELETE /api/movies - delete all
├── 📂 Billing
│   └── POST /api/billing - create order
└── 📂 Health
    └── GET /health - gateway health
```

### Run Tests

**Option 1: Run Full Collection**

1. Click ⏶ **Run Collection** button
2. Select **CRUD Master - Audit Validation Suite**
3. Click **Run**
4. View test results

**Option 2: Run Individual Request**

1. Click request name
2. Click **Send**
3. View response in **Body** tab
4. Check **Tests** tab for assertions

### Test Results

Each endpoint includes automated test scripts that verify:

- ✅ Status code (200 OK)
- ✅ Response structure
- ✅ Data validation
- ✅ Required fields present

---

## ⭐ Key Features

### 1. Microservices Architecture

- **Independent services** with separate databases
- **Loose coupling** via API Gateway and message queue
- **Easy scaling** - services can be deployed independently

### 2. Message Queue Resilience

```
Scenario: Billing API crashes while processing order

Before crash:
  Client → Gateway → RabbitMQ → Billing API → Orders DB

Order received → Queue (durable)

Crash happens:
  Order stays in RabbitMQ queue (not lost)

Billing API restarts:
  Reads all messages from queue in order
  Processes queued orders
  Inserts into database

Result: Order data is never lost (eventual consistency)
```

### 3. Reverse Proxy Pattern

**Gateway acts as reverse proxy between clients and backend services:**

```
Benefits:
- Single entry point (API Gateway at 192.168.56.10:3000)
- Clients unaware of backend service IPs/ports
- Easy to scale (add multiple backend instances)
- Can implement load balancing
- Security boundary (hide internal architecture)
- Centralized authentication/authorization
- Request logging and monitoring
```

**How it works:**

```
1. Client sends request to Gateway (only URL client knows)
2. Gateway receives request at common entry point
3. Gateway routes to appropriate backend service
4. Backend processes request
5. Gateway returns response to client
6. Client never directly contacts backend
```

### 4. HTTP Proxy Pattern

**Implementation detail of how reverse proxy forwards requests:**

```
HTTP Proxy forwarding:
- Gateway uses requests library to forward
- Preserves HTTP method (GET, POST, PUT, DELETE)
- Preserves headers (Content-Type, etc)
- Preserves request body (JSON payload)
- Preserves query parameters (?title=X)

Example:
  Client → Gateway:
    POST /api/movies
      with {"title": "Movie"}

  Gateway forwards to Inventory API:
    POST http://192.168.56.11:8080/api/movies
      with same headers and body

  Response flows back through Gateway to Client
```

### 5. Database Isolation

- Each service has **own database**
- No direct database access from other services
- Data consistency through API contracts

### 6. Infrastructure as Code

- **Vagrantfile** defines entire infrastructure
- Reproducible across machines
- Version controlled
- Easy to recreate

### 7. Comprehensive Testing

- **Postman collection** with 9 endpoints
- **Automated test scripts** for each endpoint
- **Pre-request scripts** for setup
- Export results for reporting

---

## 🔍 Troubleshooting

### Problem: VMs Won't Start

**Error**: VirtualBox error or VM startup failure

**Solution**:

```bash
# Destroy and recreate
vagrant destroy -f
vagrant up

# Check VirtualBox
virtualbox --help

# Monitor VM startup
vagrant up --debug
```

---

### Problem: API Gateway Returns 502 (Bad Gateway)

**Error**: "Inventory API is unreachable"

**Solutions**:

```bash
# 1. Check services are running
vagrant ssh inventory-vm
sudo pm2 status

# 2. Verify port 8080 is listening
ss -tlnp | grep 8080

# 3. Check connectivity
ping 192.168.56.11

# 4. Restart service
sudo pm2 restart inventory_app
```

---

### Problem: Billing Orders Not Processed

**Error**: Orders sent but not in database

**Solutions**:

```bash
# 1. Check RabbitMQ connection
vagrant ssh billing-vm
sudo pm2 logs billing_app

# 2. Verify billing_app is running
sudo pm2 status

# 3. Check RabbitMQ queue
# (requires RabbitMQ CLI)

# 4. Restart consumer
sudo pm2 restart billing_app
```

---

### Problem: Database Connection Error

**Error**: "Could not connect to database"

**Solutions**:

```bash
# 1. Check PostgreSQL in running
vagrant ssh inventory-vm
sudo systemctl status postgresql

# 2. Verify database exists
sudo -i -u postgres
psql -l

# 3. Check credentials in .env
cat /home/vagrant/.env

# 4. Restart PostgreSQL
sudo systemctl restart postgresql
```

---

### Problem: PM2 Commands Not Found

**Error**: "pm2: command not found"

**Solution**:

```bash
# Install PM2 globally
sudo npm install -g pm2

# Or use full path
sudo /usr/local/bin/pm2 status
```

---

## 📖 Additional Documentation

- **[CRUD_Master_README.md](CRUD_Master_README.md)** - Detailed step-by-step setup guide
- **[AUDIT_VERIFICATION_CHECKLIST.md](AUDIT_VERIFICATION_CHECKLIST.md)** - Audit requirements and test procedures
- **[POSTMAN_VERIFICATION_REPORT.md](POSTMAN_VERIFICATION_REPORT.md)** - Endpoint verification details
- **[openapi.yaml](openapi.yaml)** - OpenAPI/Swagger specification
- **[ENDPOINT_COVERAGE_ANALYSIS.md](ENDPOINT_COVERAGE_ANALYSIS.md)** - Complete endpoint mapping

---

## 📞 Support & Debugging

### View Service Logs

```bash
# Inventory API logs
vagrant ssh inventory-vm
tail -f /tmp/inventory.log

# Billing API logs
vagrant ssh billing-vm
sudo pm2 logs billing_app

# Gateway logs
vagrant ssh gateway-vm
sudo pm2 logs gateway_app
```

### Check Service Status

```bash
vagrant ssh inventory-vm
sudo pm2 status
```

### Manually Restart Services

```bash
# Inventory
vagrant ssh inventory-vm
sudo pm2 restart inventory_app

# Billing
vagrant ssh billing-vm
sudo pm2 restart billing_app

# Gateway
vagrant ssh gateway-vm
sudo pm2 restart gateway_app
```

---

## ✅ Verification Checklist

Before considering the project complete:

- [ ] All 3 VMs running (vagrant status shows "running")
- [ ] All services started successfully (sudo pm2 list)
- [ ] POST /api/movies returns 200 OK
- [ ] GET /api/movies returns movie list
- [ ] POST /api/billing returns 200 OK (async)
- [ ] Postman collection imported and all tests passing
- [ ] Movies in database (SELECT \* FROM movies;)
- [ ] Orders in database (SELECT \* FROM orders;)
- [ ] Message queue resilience verified (order survives billing_app restart)

---

## 📝 License

This is an educational project demonstrating microservices architecture.

---

## 🎓 Learning Outcomes

By completing this project, you'll understand:

✅ Microservices architecture design  
✅ API Gateway pattern (HTTP proxy + message routing)  
✅ Message queue implementation (RabbitMQ)  
✅ Database design and isolation  
✅ Infrastructure as Code (Vagrant)  
✅ Service resilience and eventual consistency  
✅ API testing and automation (Postman)  
✅ Container/VM provisioning

---

**Last Updated**: April 1, 2026  
**Project Status**: ✅ Complete
