import json
import boto3
import os
from urllib.parse import unquote

def move_object(s3_client, bucket_name, source_key, destination_key):
    """
    Move an object from source_key to destination_key by copying and deleting.
    """
    # Copy object to destination
    copy_source = {'Bucket': bucket_name, 'Key': source_key}
    s3_client.copy_object(
        CopySource=copy_source,
        Bucket=bucket_name,
        Key=destination_key
    )
    # Delete original object
    s3_client.delete_object(Bucket=bucket_name, Key=source_key)
    print(f"Moved s3://{bucket_name}/{source_key} -> s3://{bucket_name}/{destination_key}")

def lambda_handler(event, context):
    """
    Lambda function triggered by S3 object creation events in the "new/" folder.
    Processes uploaded documents and moves them to "processed/" on success or "failed/" on failure.
    """
    # Configure S3 client for LocalStack (if endpoint is set)
    s3_endpoint = os.environ.get('S3_ENDPOINT_URL', None)
    s3_config = {
        'region_name': os.environ.get('AWS_DEFAULT_REGION', 'us-east-1'),
        'aws_access_key_id': os.environ.get('AWS_ACCESS_KEY_ID', 'test'),
        'aws_secret_access_key': os.environ.get('AWS_SECRET_ACCESS_KEY', 'test')
    }
    if s3_endpoint:
        s3_config['endpoint_url'] = s3_endpoint
    
    s3_client = boto3.client('s3', **s3_config)
    
    # Parse S3 event
    for record in event.get('Records', []):
        # Extract bucket and key from S3 event
        bucket_name = record['s3']['bucket']['name']
        object_key = unquote(record['s3']['object']['key'])
        
        # Verify object is in "new/" folder
        if not object_key.startswith('new/'):
            print(f"Warning: Object {object_key} is not in 'new/' folder. Skipping.")
            continue
        
        print(f"Processing document: s3://{bucket_name}/{object_key}")
        
        try:
            # Get object metadata
            response = s3_client.head_object(Bucket=bucket_name, Key=object_key)
            content_type = response.get('ContentType', 'unknown')
            content_length = response.get('ContentLength', 0)
            
            print(f"Document details:")
            print(f"  - Bucket: {bucket_name}")
            print(f"  - Key: {object_key}")
            print(f"  - Content Type: {content_type}")
            print(f"  - Size: {content_length} bytes")
            
            # Download and parse JSON file
            obj_response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
            json_content = obj_response['Body'].read().decode('utf-8')
            document_data = json.loads(json_content)
            
            print(f"Parsed JSON content: {json.dumps(document_data, indent=2)}")
            
            # Check if document should fail (for testing failure path)
            # If JSON contains "should_fail": true, simulate processing failure
            should_fail = document_data.get('should_fail', False)
            processing_successful = not should_fail
            
            print(f"Processing decision: should_fail={should_fail}, processing_successful={processing_successful}")
            
            # TODO: Add actual document processing logic here
            # - Extract text from document
            # - Generate summary using AI/ML service
            # - Store summary in DynamoDB
            
            if processing_successful:
                # Move to processed folder
                # Extract filename from path (e.g., "new/document.pdf" -> "document.pdf")
                filename = object_key.replace('new/', '', 1)
                destination_key = f"processed/{filename}"
                
                move_object(s3_client, bucket_name, object_key, destination_key)
                
                summary = {
                    "status": "success",
                    "bucket": bucket_name,
                    "original_key": object_key,
                    "new_location": destination_key,
                    "content_type": content_type,
                    "size_bytes": content_length,
                    "message": "Document processed successfully and moved to processed folder."
                }
                
                print(f"Success: {json.dumps(summary, indent=2)}")
                
                return {
                    'statusCode': 200,
                    'body': json.dumps(summary)
                }
            else:
                # Simulate processing failure - move to failed folder
                raise Exception("Document processing failed")
                
        except Exception as e:
            error_msg = f"Error processing document {object_key}: {str(e)}"
            print(error_msg)
            
            try:
                # Move to failed folder
                filename = object_key.replace('new/', '', 1)
                destination_key = f"failed/{filename}"
                
                move_object(s3_client, bucket_name, object_key, destination_key)
                
                print(f"Moved failed document to: s3://{bucket_name}/{destination_key}")
                
            except Exception as move_error:
                error_msg += f" | Failed to move document: {str(move_error)}"
                print(f"Critical error: {error_msg}")
            
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'status': 'error',
                    'message': error_msg,
                    'original_key': object_key
                })
            }
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'No records to process'
        })
    }
