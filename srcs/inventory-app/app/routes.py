"""
Flask route handlers for the Inventory API.

This module handles all HTTP requests for movie CRUD operations:
- GET /api/movies - List all movies (supports ?title filter)
- POST /api/movies - Create a new movie
- DELETE /api/movies - Delete all movies
- GET /api/movies/<id> - Get a single movie by ID
- PUT /api/movies/<id> - Update a movie
- DELETE /api/movies/<id> - Delete a single movie

All endpoints return JSON responses with appropriate HTTP status codes.
"""

from flask import Blueprint, request, jsonify
from app.db import db
from app.models import Movie
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Create a Blueprint for movie routes
movies_bp = Blueprint('movies', __name__, url_prefix='/api/movies')


# ============================================================
# GET /api/movies — Retrieve all movies (with optional filtering)
# ============================================================

@movies_bp.route('', methods=['GET'])
def get_all_movies():
    """
    Retrieve all movies from the database.
    
    Query Parameters:
        title (optional): Filter movies by title (partial match)
        
    Returns:
        JSON: {
            "success": true,
            "count": <number_of_movies>,
            "movies": [<movie_objects>]
        }
        
    HTTP Status Codes:
        200: Success with movies list
        500: Server error
    """
    try:
        # Check if title filter is provided in URL query string
        title_filter = request.args.get('title')
        
        if title_filter:
            # Filter movies by title (case-insensitive partial match)
            movies = Movie.query.filter(
                Movie.title.ilike(f'%{title_filter}%')
            ).all()
        else:
            # Get all movies if no filter
            movies = Movie.query.all()
        
        # Convert all movies to dictionaries for JSON response
        movies_data = [movie.to_dict() for movie in movies]
        
        return jsonify({
            'success': True,
            'count': len(movies_data),
            'movies': movies_data
        }), 200
        
    except Exception as e:
        logger.error(f"Error fetching movies: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred while fetching movies',
            'details': str(e)
        }), 500


# ============================================================
# POST /api/movies — Create a new movie
# ============================================================

@movies_bp.route('', methods=['POST'])
def create_movie():
    """
    Create a new movie in the database.
    
    Request Body (JSON):
        {
            "title": "Movie Title" (required),
            "genre": "Action" (required),
            "release_year": 2023 (required),
            "description": "Movie description" (optional),
            "rating": 8.5 (optional),
            "duration": 120 (optional, default 120),
            "available_copies": 5 (optional, default 0)
        }
        
    Returns:
        JSON: {
            "success": true,
            "movie": <created_movie_object>,
            "message": "Movie created successfully"
        }
        
    HTTP Status Codes:
        201: Movie created successfully
        400: Missing required fields or invalid data
        500: Server error
    """
    try:
        # Get JSON data from request body
        data = request.get_json()
        
        # Validate required fields
        if not data:
            return jsonify({
                'success': False,
                'error': 'No JSON data provided'
            }), 400
        
        if not data.get('title'):
            return jsonify({
                'success': False,
                'error': 'Missing required field: title'
            }), 400
        
        if not data.get('genre'):
            return jsonify({
                'success': False,
                'error': 'Missing required field: genre'
            }), 400
        
        if not data.get('release_year'):
            return jsonify({
                'success': False,
                'error': 'Missing required field: release_year'
            }), 400
        
        # Create new Movie object with provided data
        new_movie = Movie(
            title=data['title'],
            genre=data['genre'],
            release_year=int(data['release_year']),
            description=data.get('description'),
            rating=float(data.get('rating', 0.0)),
            duration=int(data.get('duration', 120)),
            available_copies=int(data.get('available_copies', 0))
        )
        
        # Add to database session and commit
        db.session.add(new_movie)
        db.session.commit()
        
        logger.info(f"Movie created: {new_movie.title} (ID: {new_movie.id})")
        
        return jsonify({
            'success': True,
            'message': 'Movie created successfully',
            'movie': new_movie.to_dict()
        }), 201
        
    except ValueError as e:
        logger.error(f"ValueError creating movie: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Invalid data type for movie fields'
        }), 400
    except IntegrityError as e:
        db.session.rollback()
        logger.error(f"Database integrity error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Database integrity error (possibly duplicate or invalid data)'
        }), 400
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error creating movie: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred while creating the movie',
            'details': str(e)
        }), 500


# ============================================================
# GET /api/movies/<id> — Retrieve a single movie by ID
# ============================================================

@movies_bp.route('/<int:movie_id>', methods=['GET'])
def get_movie(movie_id):
    """
    Retrieve a specific movie by its ID.
    
    Path Parameters:
        movie_id (int): The ID of the movie to retrieve
        
    Returns:
        JSON: {
            "success": true,
            "movie": <movie_object>
        }
        
    HTTP Status Codes:
        200: Movie found
        404: Movie not found
        500: Server error
    """
    try:
        # Query for movie by primary key
        movie = Movie.query.get(movie_id)
        
        if not movie:
            return jsonify({
                'success': False,
                'error': f'Movie with ID {movie_id} not found'
            }), 404
        
        return jsonify({
            'success': True,
            'movie': movie.to_dict()
        }), 200
        
    except Exception as e:
        logger.error(f"Error fetching movie {movie_id}: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred while fetching the movie',
            'details': str(e)
        }), 500


# ============================================================
# PUT /api/movies/<id> — Update a movie
# ============================================================

@movies_bp.route('/<int:movie_id>', methods=['PUT'])
def update_movie(movie_id):
    """
    Update an existing movie.
    
    Path Parameters:
        movie_id (int): The ID of the movie to update
        
    Request Body (JSON):
        Any of these fields can be updated:
        {
            "title": "New Title",
            "genre": "New Genre",
            "release_year": 2024,
            "description": "Updated description",
            "rating": 9.0,
            "duration": 130,
            "available_copies": 10
        }
        
    Returns:
        JSON: {
            "success": true,
            "movie": <updated_movie_object>,
            "message": "Movie updated successfully"
        }
        
    HTTP Status Codes:
        200: Movie updated successfully
        404: Movie not found
        400: Invalid data
        500: Server error
    """
    try:
        # Get JSON data from request body
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No JSON data provided'
            }), 400
        
        # Find the movie to update
        movie = Movie.query.get(movie_id)
        
        if not movie:
            return jsonify({
                'success': False,
                'error': f'Movie with ID {movie_id} not found'
            }), 404
        
        # Update fields if provided in request body
        if 'title' in data:
            movie.title = data['title']
        if 'genre' in data:
            movie.genre = data['genre']
        if 'release_year' in data:
            movie.release_year = int(data['release_year'])
        if 'description' in data:
            movie.description = data['description']
        if 'rating' in data:
            movie.rating = float(data['rating'])
        if 'duration' in data:
            movie.duration = int(data['duration'])
        if 'available_copies' in data:
            movie.available_copies = int(data['available_copies'])
        
        # Commit changes to database
        db.session.commit()
        
        logger.info(f"Movie updated: {movie.title} (ID: {movie.id})")
        
        return jsonify({
            'success': True,
            'message': 'Movie updated successfully',
            'movie': movie.to_dict()
        }), 200
        
    except ValueError as e:
        logger.error(f"ValueError updating movie: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Invalid data type for movie fields'
        }), 400
    except IntegrityError as e:
        db.session.rollback()
        logger.error(f"Database integrity error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Database integrity error'
        }), 400
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error updating movie {movie_id}: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred while updating the movie',
            'details': str(e)
        }), 500


# ============================================================
# DELETE /api/movies/<id> — Delete a single movie
# ============================================================

@movies_bp.route('/<int:movie_id>', methods=['DELETE'])
def delete_movie(movie_id):
    """
    Delete a specific movie by its ID.
    
    Path Parameters:
        movie_id (int): The ID of the movie to delete
        
    Returns:
        JSON: {
            "success": true,
            "message": "Movie deleted successfully"
        }
        
    HTTP Status Codes:
        200: Movie deleted successfully
        404: Movie not found
        500: Server error
    """
    try:
        # Find the movie to delete
        movie = Movie.query.get(movie_id)
        
        if not movie:
            return jsonify({
                'success': False,
                'error': f'Movie with ID {movie_id} not found'
            }), 404
        
        # Delete from database
        db.session.delete(movie)
        db.session.commit()
        
        logger.info(f"Movie deleted: {movie.title} (ID: {movie_id})")
        
        return jsonify({
            'success': True,
            'message': 'Movie deleted successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error deleting movie {movie_id}: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred while deleting the movie',
            'details': str(e)
        }), 500


# ============================================================
# DELETE /api/movies — Delete all movies
# ============================================================

@movies_bp.route('', methods=['DELETE'])
def delete_all_movies():
    """
    Delete ALL movies from the database.
    
    ⚠️  WARNING: This is a destructive operation!
    
    Returns:
        JSON: {
            "success": true,
            "message": "All movies deleted successfully",
            "deleted_count": <number_deleted>
        }
        
    HTTP Status Codes:
        200: All movies deleted successfully
        500: Server error
    """
    try:
        # Count movies before deletion for response
        count = Movie.query.count()
        
        # Delete all movies
        Movie.query.delete()
        db.session.commit()
        
        logger.warning(f"All movies deleted! Count: {count}")
        
        return jsonify({
            'success': True,
            'message': 'All movies deleted successfully',
            'deleted_count': count
        }), 200
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error deleting all movies: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred while deleting all movies',
            'details': str(e)
        }), 500
