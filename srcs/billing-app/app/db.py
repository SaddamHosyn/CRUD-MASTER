"""
Billing App Database Configuration
Purpose: Initialize SQLAlchemy ORM for the orders database
Reference: CRUD_Master_README.md Section 7.2
"""

import os
from flask_sqlalchemy import SQLAlchemy

# Build PostgreSQL connection URI from environment variables
# Format: postgresql://[user]:[password]@[host]:[port]/[database]
DATABASE_URI = (
    f"postgresql://{os.environ.get('BILLING_DB_USER', 'billing_user')}:"
    f"{os.environ.get('BILLING_DB_PASSWORD', 'billing_pass')}@"
    f"{os.environ.get('BILLING_DB_HOST', 'localhost')}:"
    f"{os.environ.get('BILLING_DB_PORT', '5432')}/"
    f"{os.environ.get('BILLING_DB_NAME', 'orders')}"
)

# Initialize SQLAlchemy ORM
db = SQLAlchemy()
