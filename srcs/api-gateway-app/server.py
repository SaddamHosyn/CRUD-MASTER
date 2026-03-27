"""
API Gateway Entry Point
Purpose: Start the API Gateway server
Reference: CRUD_Master_README.md Section 8.4

The API Gateway is the single entry point for all external client requests:
- Routes HTTP requests to appropriate backend services
- Proxies /api/movies/* to Inventory API
- Publishes /api/billing events to RabbitMQ queue
"""

import os
import sys
from dotenv import load_dotenv

# CRITICAL: Load environment variables FIRST (before importing app)
load_dotenv()

from app import create_app


def main():
    """
    Main entry point for API Gateway service
    
    Sequence:
    1. Load .env file
    2. Validate environment variables
    3. Create Flask app
    4. Start server on configured port (default 3000)
    """
    
    print("=" * 70)
    print("🚪 API GATEWAY - Starting HTTP Server")
    print("=" * 70)
    
    # Validate environment variables
    required_vars = [
        'INVENTORY_IP',
        'INVENTORY_PORT',
        'RABBITMQ_HOST',
        'RABBITMQ_PORT',
        'RABBITMQ_USER',
        'RABBITMQ_PASSWORD',
        'RABBITMQ_QUEUE',
        'GATEWAY_PORT'
    ]
    
    print("\n[Startup] Validating environment variables...")
    missing_vars = []
    for var in required_vars:
        value = os.environ.get(var)
        if not value:
            missing_vars.append(var)
            print(f"  ❌ {var}: NOT SET")
        else:
            # Don't print sensitive values
            if 'PASSWORD' in var:
                print(f"  ✅ {var}: ••••••••")
            else:
                print(f"  ✅ {var}: {value}")
    
    if missing_vars:
        print(f"\n[Startup] ❌ ERROR: Missing environment variables:")
        for var in missing_vars:
            print(f"  - {var}")
        print("\n[Startup] Please ensure .env file is present and readable.")
        sys.exit(1)
    
    print("\n[Startup] ✅ All environment variables validated")
    
    # Create Flask app
    print("\n[Startup] Creating Flask application...")
    app = create_app()
    print("[Startup] ✅ Flask app created with routes registered")
    
    # Get server configuration
    gateway_port = int(os.environ.get('GATEWAY_PORT', '3000'))
    inventory_ip = os.environ.get('INVENTORY_IP')
    inventory_port = os.environ.get('INVENTORY_PORT')
    rabbitmq_host = os.environ.get('RABBITMQ_HOST')
    
    print("\n[Startup] ✅ All initialization complete")
    print("[Startup] Starting Flask development server...")
    print("-" * 70)
    print("\n📍 API GATEWAY is listening on: http://0.0.0.0:{}\n".format(gateway_port))
    print("📍 Proxying /api/movies/* to Inventory API: http://{}:{}".format(
        inventory_ip, inventory_port))
    print("📍 Publishing /api/billing to RabbitMQ at: {}".format(rabbitmq_host))
    print("\n" + "-" * 70 + "\n")
    
    # Available endpoints
    print("Available API Gateway endpoints:")
    print("  GET    /api/movies           → Get all movies (supports ?title=filter)")
    print("  POST   /api/movies           → Create a new movie")
    print("  DELETE /api/movies           → Delete all movies")
    print("  GET    /api/movies/{id}      → Get movie by ID")
    print("  PUT    /api/movies/{id}      → Update movie by ID")
    print("  DELETE /api/movies/{id}      → Delete movie by ID")
    print("  POST   /api/billing          → Create order (publish to RabbitMQ)")
    print("  GET    /health               → Health check")
    print("")
    
    # Start Flask development server
    try:
        app.run(
            host='0.0.0.0',
            port=gateway_port,
            debug=False,  # Set to False for production; True for development
            use_reloader=False  # Disable reloader for PM2 compatibility
        )
    except KeyboardInterrupt:
        print("\n" + "-" * 70)
        print("[Shutdown] Received keyboard interrupt")
    except Exception as e:
        print(f"\n[Error] Fatal error: {e}")
        sys.exit(1)
    finally:
        print("[Shutdown] ✅ API Gateway stopped")
        print("=" * 70)


if __name__ == '__main__':
    main()
