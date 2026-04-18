import json
import os
from datetime import datetime

# Configuration
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL', '')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
DLQ_URL = os.environ.get('DLQ_URL', '')

def lambda_handler(event, context):
    """
    Lambda processor for EventBridge events routed to SQS
    
    Expected event structure:
    {
        "source": "aws.lambda" or "aws.ec2",
        "detail-type": "...",
        "detail": { ... }
    }
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract event details
        source = event.get('source', 'unknown')
        detail = event.get('detail', {})
        detail_type = event.get('detail-type', 'unknown')
        
        # Process the event
        processed_event = {
            'source': source,
            'detail_type': detail_type,
            'timestamp': datetime.utcnow().isoformat(),
            'processed': True,
            'detail': detail
        }
        
        print(f"Processed event: {json.dumps(processed_event)}")
        
        # In a real scenario, you would:
        # 1. Process the event data
        # 2. Store in DynamoDB
        # 3. Send notification via SNS
        # 4. Forward to another SQS queue
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Event processed successfully',
                'event': processed_event
            })
        }
        
    except Exception as e:
        print(f"Error processing event: {str(e)}")
        
        # Send to DLQ if configured
        if DLQ_URL:
            print(f"Sending failed event to DLQ: {DLQ_URL}")
            # In production: boto3 sqs.send_message(QueueUrl=DLQ_URL, MessageBody=json.dumps(event))
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Event processing failed',
                'message': str(e)
            })
        }


def process_ec2_event(detail):
    """Process EC2-specific events"""
    event_name = detail.get('eventName', '')
    instance_id = detail.get('responseElements', {}).get('instancesSet', {}).get('items', [{}])[0].get('instanceId', '')
    
    return {
        'event_type': 'ec2',
        'event_name': event_name,
        'instance_id': instance_id
    }


def process_lambda_event(detail):
    """Process Lambda-specific events"""
    function_name = detail.get('functionName', '')
    request_id = detail.get('requestId', '')
    
    return {
        'event_type': 'lambda',
        'function_name': function_name,
        'request_id': request_id
    }
