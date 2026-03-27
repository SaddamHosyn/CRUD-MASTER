from datetime import datetime
from app.db import db


class Movie(db.Model):
    """
    Movie model representing a movie in the inventory database.
    
    This table stores all movie information that will be managed by the Inventory API.
    Each movie record can be created, read, updated, or deleted via REST API endpoints.
    """
    
    # Define the table name in PostgreSQL
    __tablename__ = 'movies'
    
    # ============================================================
    # PRIMARY KEY
    # ============================================================
    
    id = db.Column(
        db.Integer,
        primary_key=True,
        autoincrement=True,
        doc="Unique identifier for each movie (auto-generated)"
    )
    
    # ============================================================
    # CORE MOVIE INFORMATION
    # ============================================================
    
    title = db.Column(
        db.String(255),
        nullable=False,
        unique=False,
        doc="Name/title of the movie (required)"
    )
    
    description = db.Column(
        db.Text,
        nullable=True,
        doc="Detailed description or synopsis of the movie (optional, can be long text)"
    )
    
    genre = db.Column(
        db.String(100),
        nullable=False,
        doc="Movie genre (e.g., 'Action', 'Comedy', 'Drama', etc.)"
    )
    
    release_year = db.Column(
        db.Integer,
        nullable=False,
        doc="Year the movie was released (e.g., 2023)"
    )
    
    rating = db.Column(
        db.Float,
        nullable=True,
        default=0.0,
        doc="Rating out of 10 (e.g., 8.5, 7.2). Optional, defaults to 0.0"
    )
    
    duration = db.Column(
        db.Integer,
        nullable=False,
        default=120,
        doc="Movie duration in minutes (e.g., 120 for 2 hours)"
    )
    
    # ============================================================
    # INVENTORY TRACKING
    # ============================================================
    
    available_copies = db.Column(
        db.Integer,
        nullable=False,
        default=0,
        doc="Number of physical/digital copies available for rent/streaming"
    )
    
    # ============================================================
    # AUDIT TIMESTAMPS
    # ============================================================
    
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=datetime.utcnow,
        doc="Timestamp when the movie record was created"
    )
    
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        doc="Timestamp when the movie record was last updated"
    )
    
    # ============================================================
    # METHODS
    # ============================================================
    
    def to_dict(self):
        """
        Convert the Movie object to a dictionary for JSON serialization.
        
        This method is used when returning movie data in REST API responses.
        It converts the SQLAlchemy model instance into a plain Python dictionary
        that can be easily serialized to JSON.
        
        Returns:
            dict: A dictionary containing all movie fields
        """
        return {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'genre': self.genre,
            'release_year': self.release_year,
            'rating': self.rating,
            'duration': self.duration,
            'available_copies': self.available_copies,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
    
    def __repr__(self):
        """String representation of the Movie object for debugging."""
        return f"<Movie(id={self.id}, title='{self.title}', year={self.release_year})>"
