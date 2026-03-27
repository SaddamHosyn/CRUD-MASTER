"""
Billing App RabbitMQ Consumer
Purpose: Consume billing messages from RabbitMQ queue and write to PostgreSQL
Reference: CRUD_Master_README.md Section 7.4
Resilience: Messages persist in durable queue when app is offline
"""

import json
import os
import pika
from app.models import Order
from app.db import db


def consume_billing_queue(app):
    """
    Start consuming messages from RabbitMQ billing_queue
    
    This function:
    1. Connects to RabbitMQ using credentials from environment variables
    2. Declares a durable queue (survives RabbitMQ restart)
    3. Sets prefetch_count=1 (process one message at a time)
    4. Waits for messages indefinitely
    5. For each message: parse JSON, create Order record, acknowledge message
    
    CRITICAL: Always call basic_ack() AFTER successful database commit.
    If you ack before writing to DB, messages are lost forever.
    
    Args:
        app (Flask.app): Flask application instance for app context
    """
    
    print("[RabbitMQ Consumer] Initializing connection to RabbitMQ...")
    
    # Read RabbitMQ credentials from environment variables
    rabbitmq_host = os.environ.get('RABBITMQ_HOST', 'localhost')
    rabbitmq_port = int(os.environ.get('RABBITMQ_PORT', '5672'))
    rabbitmq_user = os.environ.get('RABBITMQ_USER', 'rabbitmq_user')
    rabbitmq_password = os.environ.get('RABBITMQ_PASSWORD', 'rabbitmq_pass')
    rabbitmq_queue = os.environ.get('RABBITMQ_QUEUE', 'billing_queue')
    
    # Step 1: Create connection parameters with credentials
    credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_password)
    connection_params = pika.ConnectionParameters(
        host=rabbitmq_host,
        port=rabbitmq_port,
        credentials=credentials,
        heartbeat=600,  # Keep-alive heartbeat every 10 minutes
        blocked_connection_timeout=300  # Timeout after 5 minutes of no response
    )
    
    # Step 2: Establish connection to RabbitMQ
    try:
        connection = pika.BlockingConnection(connection_params)
        print(f"[RabbitMQ Consumer] ✅ Connected to RabbitMQ at {rabbitmq_host}:{rabbitmq_port}")
    except Exception as e:
        print(f"[RabbitMQ Consumer] ❌ Failed to connect to RabbitMQ: {e}")
        raise
    
    # Step 3: Create channel for communication
    channel = connection.channel()
    print("[RabbitMQ Consumer] ✅ Channel created")
    
    # Step 4: Declare queue as DURABLE
    # durable=True ensures the queue persists if RabbitMQ server restarts
    channel.queue_declare(queue=rabbitmq_queue, durable=True)
    print(f"[RabbitMQ Consumer] ✅ Queue '{rabbitmq_queue}' declared as durable")
    
    # Step 5: Set Quality of Service (QoS)
    # prefetch_count=1 means: deliver only 1 message at a time
    # This ensures we process messages one at a time, preventing overload
    channel.basic_qos(prefetch_count=1)
    print("[RabbitMQ Consumer] ✅ QoS set to 1 (process one message at a time)")
    
    # Step 6: Define the message callback function
    def on_message_received(ch, method, properties, body):
        """
        Callback function: runs when a message arrives from the queue
        
        Args:
            ch: Channel object
            method: Delivery metadata (includes delivery_tag for acknowledgment)
            properties: Message properties
            body: Message content (bytes)
        """
        
        try:
            print(f"\n[Message #{method.delivery_tag}] Received from queue...")
            
            # Parse the message body (JSON)
            message_data = json.loads(body.decode('utf-8'))
            print(f"[Message #{method.delivery_tag}] Content: {message_data}")
            
            # Extract order details from message
            user_id = message_data.get('user_id')
            number_of_items = message_data.get('number_of_items')
            total_amount = message_data.get('total_amount')
            
            # Validate that all required fields are present
            if not all([user_id, number_of_items, total_amount]):
                print(f"[Message #{method.delivery_tag}] ❌ Invalid message format (missing fields)")
                # Acknowledge anyway to prevent infinite retry loops
                ch.basic_ack(delivery_tag=method.delivery_tag)
                return
            
            print(f"[Message #{method.delivery_tag}] Extracted: user_id={user_id}, items={number_of_items}, amount={total_amount}")
            
            # Create new Order object in app context
            with app.app_context():
                # Step 7: Create new Order record
                order = Order(
                    user_id=user_id,
                    number_of_items=number_of_items,
                    total_amount=total_amount
                )
                
                # Step 8: Add to database session
                db.session.add(order)
                print(f"[Message #{method.delivery_tag}] ✅ Order object created")
                
                # Step 9: Commit to database (BEFORE acknowledging the message)
                db.session.commit()
                print(f"[Message #{method.delivery_tag}] ✅ Order committed to PostgreSQL database (ID: {order.id})")
            
            # Step 10: Acknowledge the message ONLY AFTER successful DB commit
            # This tells RabbitMQ: "I've successfully processed this message"
            # If this line fails, the message remains in the queue for redelivery
            ch.basic_ack(delivery_tag=method.delivery_tag)
            print(f"[Message #{method.delivery_tag}] ✅ Message acknowledged to RabbitMQ")
            
        except json.JSONDecodeError:
            print(f"[Message #{method.delivery_tag}] ❌ Failed to parse JSON: {body}")
            # Acknowledge to prevent infinite loops
            ch.basic_ack(delivery_tag=method.delivery_tag)
        except Exception as e:
            print(f"[Message #{method.delivery_tag}] ❌ Error processing message: {e}")
            # Don't acknowledge - let RabbitMQ redeliver the message
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
            print(f"[Message #{method.delivery_tag}] Message requeued for retry")
    
    # Step 11: Register the callback function
    channel.basic_consume(
        queue=rabbitmq_queue,
        on_message_callback=on_message_received,
        auto_ack=False  # Don't auto-acknowledge; we'll do it manually after DB commit
    )
    
    print(f"\n[RabbitMQ Consumer] ✅ Waiting for messages on queue '{rabbitmq_queue}'...")
    print("[RabbitMQ Consumer] Listening indefinitely. Press Ctrl+C to stop.\n")
    
    # Step 12: Start consuming (blocks forever)
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print("\n[RabbitMQ Consumer] Keyboard interrupt received. Stopping consumer...")
        channel.stop_consuming()
        connection.close()
        print("[RabbitMQ Consumer] ✅ Connection closed")
