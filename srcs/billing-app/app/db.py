"""
Billing App Database Configuration
Purpose: Initialize SQLAlchemy ORM for the orders database
Reference: CRUD_Master_README.md Section 7.2
"""

import os
from flask_sqlalchemy import SQLAlchemy

# Build PostgreSQL connection URI from required environment variables.
# Format: postgresql://[user]:[password]@[host]:[port]/[database]
DATABASE_URI = (
    f"postgresql://{os.environ['BILLING_DB_USER']}:"
    f"{os.environ['BILLING_DB_PASSWORD']}@"
    f"{os.environ['BILLING_DB_HOST']}:"
    f"{os.environ['BILLING_DB_PORT']}/"
    f"{os.environ['BILLING_DB_NAME']}"
)

# Initialize SQLAlchemy ORM
db = SQLAlchemy()
