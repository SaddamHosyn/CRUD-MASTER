"""
API Gateway App Factory
Purpose: Initialize Flask app with proxy and publisher routes

Routes:
- /api/movies/* → HTTP proxy to Inventory API
- /api/billing POST → Publish to RabbitMQ queue (not HTTP proxy)
"""

import os
from flask import Flask, jsonify, request
import requests
import json
import pika


def create_app():
    """
    Flask app factory for API Gateway
    
    Creates and configures a Flask application instance that:
    - Proxies /api/movies/* requests to the Inventory API via HTTP
    - Publishes /api/billing orders to RabbitMQ queue (async, message-driven)
    
    Returns:
        Flask: Configured Flask application instance
    """
    
    app = Flask(__name__)
    
    # Read Inventory API location from environment
    inventory_ip = os.environ.get('INVENTORY_IP', 'localhost')
    inventory_port = os.environ.get('INVENTORY_PORT', '8080')
    INVENTORY_URL = f"http://{inventory_ip}:{inventory_port}"
    
    print(f"[Gateway] Inventory API target: {INVENTORY_URL}")
    
    # ================================================================
    # SECTION 1: HTTP PROXY ROUTES FOR /api/movies/*
    # ================================================================
    
    @app.route('/api/movies', methods=['GET', 'POST', 'DELETE'], strict_slashes=False)
    def proxy_movies_list():
        """
        Proxy: GET /api/movies, POST /api/movies, DELETE /api/movies
        
        - GET: Returns all movies from inventory (supports ?title=X query filter)
        - POST: Creates a new movie
        - DELETE: Deletes all movies
        
        All requests are forwarded to Inventory API via HTTP.
        Response codes, headers, and body are passed through unchanged.
        """
        
        try:
            # Build target URL
            target_url = f"{INVENTORY_URL}/api/movies"
            
            # Forward the request to Inventory API
            response = requests.request(
                method=request.method,
                url=target_url,
                json=request.get_json() if request.method in ['POST', 'PUT'] else None,
                params=request.args,  # Pass query parameters (?title=X)
                headers=request.headers,
                timeout=10
            )
            
            # Return response as-is from Inventory API
            return response.content, response.status_code, dict(response.headers)
            
        except requests.exceptions.ConnectionError:
            # Inventory API is unreachable/offline
            return jsonify({
                'error': 'Inventory API is unreachable',
                'message': f'Could not reach {INVENTORY_URL}'
            }), 502
        except requests.exceptions.Timeout:
            return jsonify({
                'error': 'Inventory API timeout',
                'message': 'Request to inventory API took too long'
            }), 504
        except Exception as e:
            return jsonify({
                'error': 'Gateway error',
                'message': str(e)
            }), 500
    
    @app.route('/api/movies/<int:movie_id>', methods=['GET', 'PUT', 'DELETE'], strict_slashes=False)
    def proxy_movies_by_id(movie_id):
        """
        Proxy: GET /api/movies/{id}, PUT /api/movies/{id}, DELETE /api/movies/{id}
        
        - GET: Fetch a specific movie by ID
        - PUT: Update a specific movie by ID
        - DELETE: Delete a specific movie by ID
        
        The {id} path parameter is forwarded to the Inventory API.
        """
        
        try:
            # Build target URL with movie ID
            target_url = f"{INVENTORY_URL}/api/movies/{movie_id}"
            
            # Forward the request
            response = requests.request(
                method=request.method,
                url=target_url,
                json=request.get_json() if request.method in ['POST', 'PUT'] else None,
                params=request.args,
                headers=request.headers,
                timeout=10
            )
            
            return response.content, response.status_code, dict(response.headers)
            
        except requests.exceptions.ConnectionError:
            return jsonify({
                'error': 'Inventory API is unreachable',
                'message': f'Could not reach {INVENTORY_URL}'
            }), 502
        except requests.exceptions.Timeout:
            return jsonify({
                'error': 'Inventory API timeout',
                'message': 'Request to inventory API took too long'
            }), 504
        except Exception as e:
            return jsonify({
                'error': 'Gateway error',
                'message': str(e)
            }), 500
    
    # ================================================================
    # SECTION 2: RABBITQ PUBLISHER ROUTE FOR /api/billing
    # ================================================================
    
    @app.route('/api/billing', methods=['POST'], strict_slashes=False)
    def publish_to_billing_queue():
        """
        RabbitMQ Publisher: POST /api/billing
        
        This route does NOT proxy to an HTTP endpoint.
        Instead, it publishes the order message to RabbitMQ's billing_queue.
        
        Expected request body (JSON):
        {
            "user_id": "user123",
            "number_of_items": "5",
            "total_amount": "49.99"
        }
        
        Response: 200 OK (immediately, asynchronously)
        
        Important: The gateway returns 200 even if Billing API is offline.
        The message will wait in the queue until Billing API comes back online.
        This is what enables resilience.
        """
        
        try:
            # Get order data from request body
            order_data = request.get_json()
            
            if not order_data:
                return jsonify({'error': 'Request body is required (JSON)'}), 400
            
            # Validate required fields
            required_fields = ['user_id', 'number_of_items', 'total_amount']
            missing = [f for f in required_fields if f not in order_data]
            
            if missing:
                return jsonify({
                    'error': 'Missing required fields',
                    'missing_fields': missing
                }), 400
            
            # Read RabbitMQ configuration from environment
            rabbitmq_host = os.environ.get('RABBITMQ_HOST', 'localhost')
            rabbitmq_port = int(os.environ.get('RABBITMQ_PORT', '5672'))
            rabbitmq_user = os.environ['RABBITMQ_USER']
            rabbitmq_password = os.environ['RABBITMQ_PASSWORD']
            rabbitmq_queue = os.environ.get('RABBITMQ_QUEUE', 'billing_queue')
            
            print(f"[Gateway] Publishing order to RabbitMQ/queue: {rabbitmq_queue}")
            print(f"[Gateway] Order data: {order_data}")
            
            # Connect to RabbitMQ
            credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_password)
            params = pika.ConnectionParameters(
                host=rabbitmq_host,
                port=rabbitmq_port,
                credentials=credentials,
                heartbeat=600,
                blocked_connection_timeout=300
            )
            
            connection = pika.BlockingConnection(params)
            channel = connection.channel()
            
            # Declare queue as durable (survives RabbitMQ server restart)
            channel.queue_declare(queue=rabbitmq_queue, durable=True)
            
            # Publish message with delivery_mode=2 (persistent)
            # Persistent messages survive RabbitMQ server restart
            channel.basic_publish(
                exchange='',
                routing_key=rabbitmq_queue,
                body=json.dumps(order_data),
                properties=pika.BasicProperties(
                    delivery_mode=2  # Make message persistent
                )
            )
            
            print(f"[Gateway] ✅ Order published to RabbitMQ queue")
            
            # Close connection immediately after publishing
            connection.close()
            
            # Return 200 OK immediately (before Billing API processes it)
            # This is what allows gateway to return success even if Billing API is down
            return jsonify({
                'message': 'Order accepted and queued for processing',
                'order': order_data
            }), 200
            
        except json.JSONDecodeError:
            return jsonify({'error': 'Invalid JSON in request body'}), 400
        except pika.exceptions.ProbableAuthenticationError:
            return jsonify({'error': 'RabbitMQ authentication failed'}), 503
        except pika.exceptions.AMQPConnectionError:
            return jsonify({
                'error': 'Cannot connect to RabbitMQ',
                'message': f'RabbitMQ server at {rabbitmq_host}:{rabbitmq_port} is unreachable'
            }), 503
        except Exception as e:
            return jsonify({
                'error': 'Error publishing order to queue',
                'message': str(e)
            }), 500
    
    # ================================================================
    # HEALTH CHECK ENDPOINT
    # ================================================================
    
    @app.route('/health', methods=['GET'], strict_slashes=False)
    def health_check():
        """
        Health check endpoint
        
        Returns 200 OK if the gateway is running.
        Does not check if downstream services are available.
        """
        return jsonify({
            'status': 'healthy',
            'service': 'API Gateway',
            'inventory_api': f"{INVENTORY_URL}",
            'rabbit_mq_host': os.environ.get('RABBITMQ_HOST', 'localhost')
        }), 200
    
    return app
