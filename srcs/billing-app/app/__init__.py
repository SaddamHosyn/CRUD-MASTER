"""
Billing App Factory
Purpose: Initialize Flask app, configure database, and export app instance
Reference: CRUD_Master_README.md Section 7.2-7.5
"""

import os
from flask import Flask
from app.db import db, DATABASE_URI


def create_app():
    """
    Flask app factory
    
    Creates and configures a Flask application instance with:
    - SQLAlchemy ORM initialized
    - Database tables created (if missing)
    - All models registered
    
    Returns:
        Flask: Configured Flask application instance
    """
    
    # Create Flask app instance
    app = Flask(__name__)
    
    # Configure SQLAlchemy
    app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False  # Disable metadata tracking (performance)
    
    print("[Billing App] Initializing SQLAlchemy database...")
    
    # Initialize database with app
    db.init_app(app)
    
    # Create all tables inside app context
    with app.app_context():
        print("[Billing App] Creating database tables (if missing)...")
        db.create_all()
        print("[Billing App] ✅ Database tables ready")
    
    return app
