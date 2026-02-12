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
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request as StarletteRequest
from starlette.responses import Response
from mangum import Mangum

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize FastAPI app
# Note: Don't use root_path here - Mangum handles path construction from API Gateway events
app = FastAPI(
    title="S3 Upload API",
    description="API for uploading files to S3 bucket",
    version="1.0.0"
)


class StripPathPrefixMiddleware(BaseHTTPMiddleware):
    """Middleware to strip /api prefix from request paths."""
    async def dispatch(self, request: Request, call_next):
        # Strip /api prefix if present (handle both /api/health and /api/api/health cases)
        original_path = request.url.path
        logger.info(f"Original path: {original_path}, scope path_info: {request.scope.get('path_info', 'N/A')}")
        
        # Remove all leading /api prefixes (handles double prefix case)
        new_path = original_path
        while new_path.startswith("/api"):
            new_path = new_path[4:] or "/"
        
        if new_path != original_path:
            # Create a completely new scope with updated paths
            scope = request.scope.copy()
            scope["path"] = new_path
            scope["raw_path"] = new_path.encode()
            scope["path_info"] = new_path  # This is critical for FastAPI routing
            scope["root_path"] = ""  # Clear root_path
            # Also update the query string path if present
            if "query_string" in scope:
                # Keep query string as is
                pass
            
            # Create new request with updated scope - use StarletteRequest for proper construction
            request = Request(scope, request.receive)
            logger.info(f"Path rewritten: {original_path} -> {new_path} (path_info={request.scope.get('path_info')})")
        else:
            logger.info(f"Path does not start with /api, keeping as: {original_path}")
        
        response = await call_next(request)
        logger.info(f"Response status: {response.status_code if hasattr(response, 'status_code') else 'N/A'}")
        return response


# Add path stripping middleware first (before CORS)
app.add_middleware(StripPathPrefixMiddleware)

# Configure CORS - must be after path stripping middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=3600,
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

# Also add route with /api prefix as fallback (in case middleware doesn't work)
@app.get("/api/health")
async def health_with_prefix():
    """Health check endpoint with /api prefix (fallback)."""
    return await health()

@app.get("/health")
async def health():
    """Detailed health check."""
    s3_endpoint = os.environ.get('S3_ENDPOINT_URL', 'AWS (default)')
    bucket_name = S3_BUCKET_NAME
    
    try:
        s3_client = get_s3_client()
        
        # Try to check bucket accessibility using list_objects_v2 (more reliable than head_bucket)
        # This requires s3:ListBucket permission which we have
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            MaxKeys=1  # Just check if we can access, don't need actual objects
        )
        
        return {
            "status": "healthy",
            "bucket": bucket_name,
            "accessible": True,
            "s3_endpoint": s3_endpoint,
            "region": os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
        }
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        error_message = e.response.get('Error', {}).get('Message', str(e))
        logger.error(f"S3 health check failed: {error_code} - {error_message}")
        logger.error(f"Bucket: {bucket_name}, Endpoint: {s3_endpoint}")
        
        # Return 200 with error details instead of raising exception
        # This allows the frontend to display the error message
        return {
            "status": "unhealthy",
            "bucket": bucket_name,
            "accessible": False,
            "error": {
                "code": error_code,
                "message": error_message
            },
            "s3_endpoint": s3_endpoint,
            "region": os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
        }
    except Exception as e:
        logger.error(f"Unexpected error during health check: {str(e)}", exc_info=True)
        return {
            "status": "unhealthy",
            "bucket": bucket_name,
            "accessible": False,
            "error": {
                "code": "UnexpectedError",
                "message": str(e)
            },
            "s3_endpoint": s3_endpoint,
            "region": os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
        }


# Fallback route with /api prefix
@app.post("/api/upload")
async def upload_file_with_prefix(
    file: UploadFile = File(...),
    folder: Optional[str] = Form(None)
):
    """Upload endpoint with /api prefix (fallback)."""
    return await upload_file(file, folder)

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


# Fallback route with /api prefix
@app.post("/api/upload/json")
async def upload_json_file_with_prefix(
    file: UploadFile = File(...)
):
    """Upload JSON endpoint with /api prefix (fallback)."""
    return await upload_json_file(file)

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
# text_mime_types ensures proper content-type handling
handler = Mangum(
    app, 
    lifespan="off",
    text_mime_types=["application/json", "text/plain"]
)
