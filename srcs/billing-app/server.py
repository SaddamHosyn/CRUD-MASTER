"""
Billing App Entry Point
Purpose: Start the Billing API (RabbitMQ message consumer)
Reference: CRUD_Master_README.md Section 7.5

IMPORTANT: This app does NOT serve HTTP requests.
Instead, it connects to RabbitMQ and consumes messages from the billing_queue.
It blocks indefinitely, listening for order events.
"""

import os
import sys
from dotenv import load_dotenv

# CRITICAL: Load environment variables FIRST (before importing app)
# This ensures DATABASE_URI and RABBITMQ credentials are available
load_dotenv()

from app import create_app
from app.consumer import consume_billing_queue


def main():
    """
    Main entry point for Billing API service
    
    Sequence:
    1. Load .env file (already done above)
    2. Validate required environment variables
    3. Create Flask app with SQLAlchemy initialization
    4. Start RabbitMQ consumer (blocks indefinitely)
    """
    
    print("=" * 60)
    print("💳 BILLING API - Starting RabbitMQ Consumer")
    print("=" * 60)
    
    # Validate environment variables are loaded
    required_vars = [
        'BILLING_DB_NAME',
        'BILLING_DB_USER',
        'BILLING_DB_PASSWORD',
        'BILLING_DB_HOST',
        'BILLING_DB_PORT',
        'RABBITMQ_HOST',
        'RABBITMQ_PORT',
        'RABBITMQ_USER',
        'RABBITMQ_PASSWORD',
        'RABBITMQ_QUEUE'
    ]
    
    print("\n[Startup] Validating environment variables...")
    missing_vars = []
    for var in required_vars:
        value = os.environ.get(var)
        if not value:
            missing_vars.append(var)
            print(f"  ❌ {var}: NOT SET")
        else:
            # Don't print actual password values
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
    print("[Startup] ✅ Flask app created")
    
    # Start RabbitMQ consumer (this blocks forever)
    print("\n[Startup] ✅ All initialization complete")
    print("[Startup] Starting RabbitMQ consumer...")
    print("-" * 60)
    
    try:
        consume_billing_queue(app)
    except KeyboardInterrupt:
        print("\n" + "-" * 60)
        print("[Shutdown] Received keyboard interrupt")
    except Exception as e:
        print(f"\n[Error] Fatal error: {e}")
        sys.exit(1)
    finally:
        print("[Shutdown] ✅ Billing API consumer stopped")
        print("=" * 60)


if __name__ == '__main__':
    main()
