"""
FastAPI Lambda handler for S3 file uploads.
Uses Mangum adapter to run FastAPI on AWS Lambda.
"""
import json
import logging
import os
from typing import Optional

import boto3
from botocore.exceptions import ClientError
from fastapi import FastAPI, File, Form, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize FastAPI app
app = FastAPI(
    title="S3 Upload API",
    description="API for uploading files to S3 bucket",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize S3 client
def get_s3_client():
    """Get configured S3 client for LocalStack or AWS."""
    s3_config = {
        'region_name': os.environ.get('AWS_DEFAULT_REGION', 'us-east-1'),
        'aws_access_key_id': os.environ.get('AWS_ACCESS_KEY_ID', 'test'),
        'aws_secret_access_key': os.environ.get('AWS_SECRET_ACCESS_KEY', 'test')
    }
    
    # Use LocalStack endpoint if configured
    s3_endpoint = os.environ.get('S3_ENDPOINT_URL')
    if s3_endpoint:
        s3_config['endpoint_url'] = s3_endpoint
    
    return boto3.client('s3', **s3_config)


# Environment variables
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME', 'scrap-document-poc')
UPLOAD_PREFIX = os.environ.get('UPLOAD_PREFIX', 'new/')
MAX_FILE_SIZE = int(os.environ.get('MAX_FILE_SIZE', 10 * 1024 * 1024))  # 10MB default


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "S3 Upload API",
        "bucket": S3_BUCKET_NAME,
        "upload_prefix": UPLOAD_PREFIX
    }


@app.get("/health")
async def health():
    """Detailed health check."""
    try:
        s3_client = get_s3_client()
        # Check if bucket exists and is accessible
        s3_client.head_bucket(Bucket=S3_BUCKET_NAME)
        return {
            "status": "healthy",
            "bucket": S3_BUCKET_NAME,
            "accessible": True
        }
    except ClientError as e:
        logger.error(f"S3 health check failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"S3 bucket not accessible: {str(e)}"
        )


@app.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    folder: Optional[str] = Form(None)
):
    """
    Upload a file to S3 bucket.
    
    Args:
        file: The file to upload
        folder: Optional subfolder within the upload prefix (default: None)
    
    Returns:
        Upload result with S3 location
    """
    try:
        # Validate file size
        file_content = await file.read()
        file_size = len(file_content)
        
        if file_size > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File size {file_size} exceeds maximum allowed size {MAX_FILE_SIZE}"
            )
        
        if file_size == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File is empty"
            )
        
        # Construct S3 key
        folder_path = f"{folder}/" if folder else ""
        s3_key = f"{UPLOAD_PREFIX}{folder_path}{file.filename}"
        
        logger.info(f"Uploading file: {file.filename} ({file_size} bytes) to s3://{S3_BUCKET_NAME}/{s3_key}")
        
        # Upload to S3
        s3_client = get_s3_client()
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=file_content,
            ContentType=file.content_type or 'application/octet-stream',
            Metadata={
                'original-filename': file.filename,
                'upload-size': str(file_size)
            }
        )
        
        logger.info(f"Successfully uploaded {file.filename} to {s3_key}")
        
        return {
            "status": "success",
            "message": "File uploaded successfully",
            "bucket": S3_BUCKET_NAME,
            "key": s3_key,
            "filename": file.filename,
            "size": file_size,
            "content_type": file.content_type,
            "s3_url": f"s3://{S3_BUCKET_NAME}/{s3_key}"
        }
        
    except HTTPException:
        raise
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"S3 upload failed: {error_code} - {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file to S3: {error_code}"
        )
    except Exception as e:
        logger.error(f"Unexpected error during upload: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred during file upload"
        )


@app.post("/upload/json")
async def upload_json_file(
    file: UploadFile = File(...)
):
    """
    Upload a JSON file to S3 (validates JSON format).
    
    Args:
        file: The JSON file to upload
    
    Returns:
        Upload result with parsed JSON preview
    """
    try:
        # Read file content
        file_content = await file.read()
        file_size = len(file_content)
        
        # Validate file size
        if file_size > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File size {file_size} exceeds maximum allowed size {MAX_FILE_SIZE}"
            )
        
        # Validate JSON format
        try:
            json_data = json.loads(file_content.decode('utf-8'))
        except json.JSONDecodeError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid JSON format: {str(e)}"
            )
        
        # Construct S3 key (ensure .json extension)
        filename = file.filename or 'upload.json'
        if not filename.endswith('.json'):
            filename = f"{filename}.json"
        
        s3_key = f"{UPLOAD_PREFIX}{filename}"
        
        logger.info(f"Uploading JSON file: {filename} ({file_size} bytes) to s3://{S3_BUCKET_NAME}/{s3_key}")
        
        # Upload to S3
        s3_client = get_s3_client()
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=file_content,
            ContentType='application/json',
            Metadata={
                'original-filename': file.filename or 'upload.json',
                'upload-size': str(file_size),
                'json-keys': ','.join(json_data.keys())[:100]  # First 100 chars of keys
            }
        )
        
        logger.info(f"Successfully uploaded JSON file {filename} to {s3_key}")
        
        return {
            "status": "success",
            "message": "JSON file uploaded successfully",
            "bucket": S3_BUCKET_NAME,
            "key": s3_key,
            "filename": filename,
            "size": file_size,
            "json_preview": {
                "keys": list(json_data.keys())[:10],  # First 10 keys
                "key_count": len(json_data.keys())
            },
            "s3_url": f"s3://{S3_BUCKET_NAME}/{s3_key}"
        }
        
    except HTTPException:
        raise
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"S3 upload failed: {error_code} - {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file to S3: {error_code}"
        )
    except Exception as e:
        logger.error(f"Unexpected error during upload: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred during file upload"
        )


# Lambda handler using Mangum adapter
handler = Mangum(app, lifespan="off")
