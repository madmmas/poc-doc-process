"""
Unit tests for FastAPI S3 Upload Lambda.
Tests endpoints with moto (mocked S3 service).
Moto provides a more realistic AWS service emulation than unittest.mock.
"""
import json

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_s3


class TestHealthEndpoints:
    """Test health check endpoints."""

    def test_root_endpoint(self, client):
        """Test root health check endpoint."""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "S3 Upload API"
        assert "bucket" in data
        assert "upload_prefix" in data

    @mock_s3
    def test_health_endpoint_success(self, client):
        """Test health endpoint when S3 is accessible."""
        # Create bucket using moto
        s3_client = boto3.client('s3', region_name='us-east-1')
        bucket_name = 'test-bucket'
        s3_client.create_bucket(Bucket=bucket_name)
        
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["accessible"] is True

    @mock_s3
    def test_health_endpoint_failure(self, client):
        """Test health endpoint when S3 bucket doesn't exist."""
        # Don't create bucket - should fail
        response = client.get("/health")
        assert response.status_code == 503
        assert "not accessible" in response.json()["detail"].lower()


class TestUploadEndpoint:
    """Test file upload endpoint."""

    @mock_s3
    def test_upload_success(self, client, sample_file_content):
        """Test successful file upload."""
        # Setup: Create bucket
        s3_client = boto3.client('s3', region_name='us-east-1')
        s3_client.create_bucket(Bucket='test-bucket')
        
        response = client.post(
            "/upload",
            files={"file": ("test.txt", sample_file_content, "text/plain")}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["filename"] == "test.txt"
        assert data["size"] == len(sample_file_content)
        assert "s3_url" in data
        assert "test-uploads/" in data["key"]
        
        # Verify file was actually uploaded to moto S3
        s3_key = data["key"]
        obj = s3_client.get_object(Bucket='test-bucket', Key=s3_key)
        assert obj['Body'].read() == sample_file_content
        assert obj['ContentType'] == 'text/plain'

    @mock_s3
    def test_upload_with_folder(self, client, sample_file_content):
        """Test file upload with folder parameter."""
        # Setup: Create bucket
        s3_client = boto3.client('s3', region_name='us-east-1')
        s3_client.create_bucket(Bucket='test-bucket')
        
        # FastAPI TestClient requires form data to be sent with files
        # Use files parameter with both file and form data
        response = client.post(
            "/upload",
            data={"folder": "documents"},
            files={"file": ("test.txt", sample_file_content, "text/plain")}
        )
        
        assert response.status_code == 200
        data = response.json()
        # Check that folder is included in the key
        assert "documents/" in data["key"], f"Expected 'documents/' in key '{data['key']}'"
        assert "test-uploads/documents/" in data["key"]
        
        # Verify file exists in S3
        s3_client.head_object(Bucket='test-bucket', Key=data["key"])

    def test_upload_empty_file(self, client):
        """Test upload of empty file."""
        response = client.post(
            "/upload",
            files={"file": ("empty.txt", b"", "text/plain")}
        )
        
        assert response.status_code == 400
        assert "empty" in response.json()["detail"].lower()

    def test_upload_file_too_large(self, client):
        """Test upload of file exceeding size limit."""
        # Create file larger than 10MB
        large_content = b"x" * (11 * 1024 * 1024)
        
        response = client.post(
            "/upload",
            files={"file": ("large.txt", large_content, "text/plain")}
        )
        
        assert response.status_code == 413
        assert "exceeds" in response.json()["detail"].lower()

    @mock_s3
    def test_upload_s3_error(self, client, sample_file_content):
        """Test upload when S3 returns an error."""
        # Don't create bucket - should cause error
        response = client.post(
            "/upload",
            files={"file": ("test.txt", sample_file_content, "text/plain")}
        )
        
        assert response.status_code == 500
        assert "failed to upload" in response.json()["detail"].lower()


class TestJSONUploadEndpoint:
    """Test JSON file upload endpoint."""

    @mock_s3
    def test_upload_json_success(self, client, sample_json_content):
        """Test successful JSON file upload."""
        # Setup: Create bucket
        s3_client = boto3.client('s3', region_name='us-east-1')
        s3_client.create_bucket(Bucket='test-bucket')
        
        response = client.post(
            "/upload/json",
            files={"file": ("test.json", sample_json_content, "application/json")}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["filename"].endswith(".json")
        assert "json_preview" in data
        assert "keys" in data["json_preview"]
        assert "key_count" in data["json_preview"]
        
        # Verify JSON was uploaded and can be retrieved
        s3_key = data["key"]
        obj = s3_client.get_object(Bucket='test-bucket', Key=s3_key)
        assert obj['Body'].read() == sample_json_content
        assert obj['ContentType'] == 'application/json'
        
        # Verify JSON structure
        json_data = json.loads(sample_json_content.decode('utf-8'))
        assert data["json_preview"]["key_count"] == len(json_data.keys())

    def test_upload_json_invalid_format(self, client):
        """Test upload of invalid JSON file."""
        invalid_json = b"{invalid json content"
        
        response = client.post(
            "/upload/json",
            files={"file": ("invalid.json", invalid_json, "application/json")}
        )
        
        assert response.status_code == 400
        assert "invalid json" in response.json()["detail"].lower()

    @mock_s3
    def test_upload_json_auto_extension(self, client, sample_json_content):
        """Test that non-.json files get .json extension added."""
        # Setup: Create bucket
        s3_client = boto3.client('s3', region_name='us-east-1')
        s3_client.create_bucket(Bucket='test-bucket')
        
        response = client.post(
            "/upload/json",
            files={"file": ("test", sample_json_content, "application/json")}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["filename"].endswith(".json")
        
        # Verify file exists with .json extension
        s3_client.head_object(Bucket='test-bucket', Key=data["key"])

    def test_upload_json_large_file(self, client):
        """Test upload of JSON file exceeding size limit."""
        # Create large JSON content
        large_json = json.dumps({"data": "x" * (11 * 1024 * 1024)}).encode()
        
        response = client.post(
            "/upload/json",
            files={"file": ("large.json", large_json, "application/json")}
        )
        
        assert response.status_code == 413


class TestLambdaHandler:
    """Test Lambda handler integration with Mangum."""

    def test_lambda_handler_exists(self):
        """Test that Lambda handler is properly configured."""
        from app import handler
        assert handler is not None
        assert callable(handler)

    @mock_s3
    def test_lambda_handler_with_api_gateway_event(self):
        """Test Lambda handler with API Gateway v2 event."""
        from app import handler
        
        # Setup: Create bucket
        s3_client = boto3.client('s3', region_name='us-east-1')
        s3_client.create_bucket(Bucket='test-bucket')
        
        # Simulate API Gateway HTTP API v2 event (Mangum supports this)
        # Include all required fields that Mangum expects
        event = {
            "version": "2.0",
            "routeKey": "GET /",
            "rawPath": "/",
            "rawQueryString": "",
            "headers": {
                "host": "test.execute-api.us-east-1.amazonaws.com",
                "user-agent": "test-agent"
            },
            "requestContext": {
                "http": {
                    "method": "GET",
                    "path": "/",
                    "protocol": "HTTP/1.1",
                    "sourceIp": "127.0.0.1",  # Required by Mangum
                    "userAgent": "test-agent"
                },
                "requestId": "test-request-id",
                "stage": "dev",
                "time": "12/Jan/2024:00:00:00 +0000",
                "timeEpoch": 1704508800000,
                "domainName": "test.execute-api.us-east-1.amazonaws.com",
                "domainPrefix": "test"
            },
            "isBase64Encoded": False
        }
        
        from unittest.mock import MagicMock
        context = MagicMock()
        context.function_name = "test-function"
        context.memory_limit_in_mb = 512
        
        # Handler should process the event
        response = handler(event, context)
        
        assert response is not None
        assert "statusCode" in response
        assert response["statusCode"] == 200
