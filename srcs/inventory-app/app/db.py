import os
from flask_sqlalchemy import SQLAlchemy

# Build the database URI from required environment variables.
DATABASE_URI = (
    f"postgresql://{os.environ['INVENTORY_DB_USER']}:"
    f"{os.environ['INVENTORY_DB_PASSWORD']}@"
    f"{os.environ['INVENTORY_DB_HOST']}:"
    f"{os.environ['INVENTORY_DB_PORT']}/"
    f"{os.environ['INVENTORY_DB_NAME']}"
)

# Initialize SQLAlchemy instance
db = SQLAlchemy()