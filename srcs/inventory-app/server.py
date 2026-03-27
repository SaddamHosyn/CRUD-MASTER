#!/usr/bin/env python3
"""
Inventory API Server Entry Point

This is the main entry point for the Inventory API microservice.

Execution Steps:
1. Load environment variables from .env file (FIRST, before any imports!)
2. Import Flask app factory
3. Create app instance with all configurations
4. Start Flask server on 0.0.0.0:INVENTORY_PORT

Usage:
    python3 server.py

The server will:
- Automatically create the PostgreSQL 'movies' table on startup
- Listen on 0.0.0.0:8080 (or the port specified in INVENTORY_PORT env var)
- Expose REST endpoints at /api/movies/*
"""

# CRITICAL: Load environment variables FIRST before importing anything else!
from dotenv import load_dotenv
import os

load_dotenv()

# Now import the app factory
from app import create_app

# Verify critical environment variables are set
required_env_vars = [
    'INVENTORY_DB_USER',
    'INVENTORY_DB_PASSWORD',
    'INVENTORY_DB_HOST',
    'INVENTORY_DB_PORT',
    'INVENTORY_DB_NAME',
    'INVENTORY_PORT'
]

for var in required_env_vars:
    if not os.environ.get(var):
        print(f"❌ ERROR: Missing environment variable: {var}")
        print(f"   Make sure .env file is in the project root with all required variables")
        exit(1)

if __name__ == '__main__':
    # Create the Flask app (factory pattern)
    app = create_app()
    
    # Get server configuration from environment variables
    host = '0.0.0.0'  # Listen on all network interfaces
    port = int(os.environ['INVENTORY_PORT'])
    
    # Print startup information
    print("\n" + "="*60)
    print("🎬 INVENTORY API MICROSERVICE")
    print("="*60)
    print(f"📍 Host: {host}")
    print(f"🔌 Port: {port}")
    print(f"🗄️  Database: {os.environ['INVENTORY_DB_NAME']}")
    print(f"📊 Database User: {os.environ['INVENTORY_DB_USER']}")
    print(f"🖥️  Database Host: {os.environ['INVENTORY_DB_HOST']}")
    print("="*60)
    print("\n✅ API Endpoints Available:")
    print("   GET    /api/movies              - Get all movies")
    print("   POST   /api/movies              - Create a new movie")
    print("   DELETE /api/movies              - Delete all movies")
    print("   GET    /api/movies/<id>         - Get a single movie")
    print("   PUT    /api/movies/<id>         - Update a movie")
    print("   DELETE /api/movies/<id>         - Delete a single movie")
    print("\n🔗 Try: curl http://localhost:8080/api/movies\n")
    print("="*60 + "\n")
    
    # Start the Flask development server
    app.run(
        host=host,
        port=port,
        debug=os.environ.get('FLASK_DEBUG', 'False') == 'True'
    )
