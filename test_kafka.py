from kafka import KafkaProducer, KafkaConsumer
import json
import time
from datetime import datetime

# Create a producer to send messages
producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

print("🚀 Sending test messages to Kafka...")

# Send some example messages
messages = [
    {"event": "user_login", "user_id": 123, "timestamp": datetime.now().isoformat()},
    {"event": "page_view", "user_id": 123, "page": "/dashboard", "timestamp": datetime.now().isoformat()},
    {"event": "purchase", "user_id": 456, "product": "laptop", "amount": 999.99, "timestamp": datetime.now().isoformat()},
    {"event": "user_logout", "user_id": 123, "timestamp": datetime.now().isoformat()}
]

for i, message in enumerate(messages):
    # Send to different topics
    if message["event"] in ["user_login", "user_logout"]:
        topic = "user-events"
    elif message["event"] == "page_view":
        topic = "analytics-events"  
    else:
        topic = "purchase-events"
    
    producer.send(topic, message)
    print(f"✅ Sent to {topic}: {message}")
    time.sleep(1)

producer.flush()
producer.close()
print("\n🎉 All messages sent! Check Kafka UI at http://localhost:8080")