import json
import os
import boto3
from datetime import datetime

# AWS clients
sns_client = boto3.client('sns')
sqs_client = boto3.client('sqs')

# Environment variables
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL', '')
DLQ_URL = os.environ.get('DLQ_URL', '')
MAX_RETRIES = 3

def lambda_handler(event, context):
    """
    EventBridge Event Processor
    Receives events from EventBridge and processes them via SQS/SNS
    
    Event structure from EventBridge:
    {
        "version": "0",
        "id": "...",
        "detail-type": "...",
        "source": "aws.ec2",
        "account": "...",
        "time": "...",
        "region": "...",
        "resources": [...],
        "detail": {...}
    }
    """
    print(f"Received event: {json.dumps(event)}")
    
    # Extract event metadata
    event_id = event.get('id', '')
    event_source = event.get('source', 'unknown')
    detail_type = event.get('detail-type', 'unknown')
    detail = event.get('detail', {})
    region = event.get('region', 'us-east-1')
    
    try:
        # Process based on event source
        if event_source == 'aws.ec2':
            result = process_ec2_event(event_id, detail)
        elif event_source == 'aws.lambda':
            result = process_lambda_event(event_id, detail)
        elif event_source == 'custom.application':
            result = process_custom_event(event_id, detail)
        else:
            result = {'processed': True, 'note': f'Event source {event_source} not specifically handled'}
        
        # Add common metadata
        result['event_id'] = event_id
        result['event_source'] = event_source
        result['detail_type'] = detail_type
        result['processed_at'] = datetime.utcnow().isoformat()
        
        # Send processed event to SNS for pub/sub
        if SNS_TOPIC_ARN:
            send_sns_notification(result)
        
        # Forward to SQS queue for async processing
        if SQS_QUEUE_URL:
            forward_to_sqs(result)
        
        print(f"Event processed successfully: {json.dumps(result)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Event processed successfully',
                'result': result
            })
        }
        
    except Exception as e:
        print(f"Error processing event {event_id}: {str(e)}")
        handle_failure(event, str(e))
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Event processing failed',
                'event_id': event_id,
                'message': str(e)
            })
        }


def process_ec2_event(event_id, detail):
    """Process EC2 state change events"""
    instance_id = None
    state = None
    
    # Try different EC2 event structures
    if 'instance-id' in detail:
        instance_id = detail['instance-id']
        state = detail.get('state', 'unknown')
    elif 'responseElements' in detail:
        inst_set = detail.get('responseElements', {}).get('instancesSet', {})
        if inst_set and 'items' in inst_set and len(inst_set['items']) > 0:
            instance_id = inst_set['items'][0].get('instanceId')
            state = inst_set['items'][0].get('state', {}).get('name')
    
    return {
        'event_category': 'ec2',
        'instance_id': instance_id,
        'state': state,
        'message': f'EC2 instance {instance_id} is now {state}'
    }


def process_lambda_event(event_id, detail):
    """Process Lambda function events"""
    function_name = detail.get('functionName', detail.get('requestPayload', {}).get('functionName'))
    request_id = detail.get('requestId', detail.get('responsePayload', {}).get('requestId'))
    
    return {
        'event_category': 'lambda',
        'function_name': function_name,
        'request_id': request_id,
        'message': f'Lambda function {function_name} processed request {request_id}'
    }


def process_custom_event(event_id, detail):
    """Process custom application events"""
    event_name = detail.get('eventName', 'unknown')
    payload = detail.get('payload', {})
    
    return {
        'event_category': 'custom',
        'event_name': event_name,
        'payload': payload,
        'message': f'Custom event {event_name} processed'
    }


def send_sns_notification(message):
    """Send processed event notification via SNS"""
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(message),
            Subject=f"Processed Event: {message.get('event_category', 'unknown')}",
            MessageStructure='json'
        )
        print(f"Published to SNS: {SNS_TOPIC_ARN}")
    except Exception as e:
        print(f"Failed to publish to SNS: {str(e)}")


def forward_to_sqs(message):
    """Forward processed event to SQS queue"""
    try:
        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message),
            MessageGroupId='event-processor'
        )
        print(f"Forwarded to SQS: {SQS_QUEUE_URL}")
    except Exception as e:
        print(f"Failed to forward to SQS: {str(e)}")


def handle_failure(event, error_message):
    """Handle failed event processing - send to DLQ"""
    if DLQ_URL:
        try:
            sqs_client.send_message(
                QueueUrl=DLQ_URL,
                MessageBody=json.dumps({
                    'original_event': event,
                    'error': error_message,
                    'failed_at': datetime.utcnow().isoformat()
                }),
                MessageGroupId='failed-events'
            )
            print(f"Failed event sent to DLQ: {DLQ_URL}")
        except Exception as dlq_error:
            print(f"Failed to send to DLQ: {str(dlq_error)}")
