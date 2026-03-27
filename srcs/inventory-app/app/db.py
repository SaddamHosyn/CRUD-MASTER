import os
from flask_sqlalchemy import SQLAlchemy

# Build the database URI from environment variables (with fallbacks for development)
DATABASE_URI = (
    f"postgresql://{os.environ.get('INVENTORY_DB_USER', 'inventory_user')}:"
    f"{os.environ.get('INVENTORY_DB_PASSWORD', 'inventory_pass')}@"
    f"{os.environ.get('INVENTORY_DB_HOST', 'localhost')}:"
    f"{os.environ.get('INVENTORY_DB_PORT', '5432')}/"
    f"{os.environ.get('INVENTORY_DB_NAME', 'movies')}"
)

# Initialize SQLAlchemy instance
db = SQLAlchemy()