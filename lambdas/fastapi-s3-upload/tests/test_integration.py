"""
Integration tests for FastAPI S3 Upload Lambda.
Tests against LocalStack S3 service.
"""
import json
import os
import time

import boto3
import pytest
from botocore.exceptions import ClientError

# Integration test configuration
S3_ENDPOINT_URL = os.environ.get("S3_ENDPOINT_URL", "http://localhost:4566")
S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME", "test-integration-bucket")
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")


@pytest.fixture(scope="module")
def s3_client():
    """Create S3 client for integration tests."""
    return boto3.client(
        's3',
        endpoint_url=S3_ENDPOINT_URL,
        region_name=AWS_REGION,
        aws_access_key_id='test',
        aws_secret_access_key='test'
    )


@pytest.fixture(scope="module")
def test_bucket(s3_client):
    """Create and cleanup test bucket."""
    # Use the bucket name from environment or default
    bucket_name = os.environ.get('S3_BUCKET_NAME', f"{S3_BUCKET_NAME}-{int(time.time())}")
    
    try:
        # Create bucket if it doesn't exist
        try:
            s3_client.head_bucket(Bucket=bucket_name)
        except ClientError:
            # Bucket doesn't exist, create it
            s3_client.create_bucket(Bucket=bucket_name)
        
        yield bucket_name
        
        # Cleanup: Delete all objects and bucket
        try:
            objects = s3_client.list_objects_v2(Bucket=bucket_name)
            if 'Contents' in objects:
                for obj in objects['Contents']:
                    s3_client.delete_object(Bucket=bucket_name, Key=obj['Key'])
            s3_client.delete_bucket(Bucket=bucket_name)
        except Exception as e:
            print(f"Cleanup warning: {e}")
    except Exception as e:
        print(f"Setup error: {e}")
        raise


@pytest.fixture
def test_file_content():
    """Test file content."""
    return b"This is a test file for integration testing"


@pytest.fixture
def test_json_content():
    """Test JSON content."""
    return json.dumps({"test": "integration", "timestamp": time.time()}).encode()


@pytest.mark.integration
class TestS3Integration:
    """Integration tests with real S3 operations."""

    def test_bucket_exists(self, s3_client, test_bucket):
        """Test that test bucket exists and is accessible."""
        response = s3_client.head_bucket(Bucket=test_bucket)
        assert response is not None

    def test_upload_file_to_s3(self, s3_client, test_bucket, test_file_content):
        """Test uploading a file directly to S3."""
        key = "test-uploads/integration-test.txt"
        
        s3_client.put_object(
            Bucket=test_bucket,
            Key=key,
            Body=test_file_content,
            ContentType='text/plain'
        )
        
        # Verify file exists
        response = s3_client.head_object(Bucket=test_bucket, Key=key)
        assert response['ContentLength'] == len(test_file_content)
        assert response['ContentType'] == 'text/plain'

    def test_upload_json_to_s3(self, s3_client, test_bucket, test_json_content):
        """Test uploading JSON file to S3."""
        key = "test-uploads/integration-test.json"
        
        s3_client.put_object(
            Bucket=test_bucket,
            Key=key,
            Body=test_json_content,
            ContentType='application/json'
        )
        
        # Verify and read back
        response = s3_client.get_object(Bucket=test_bucket, Key=key)
        content = response['Body'].read()
        assert content == test_json_content
        
        # Verify it's valid JSON
        json_data = json.loads(content.decode('utf-8'))
        assert json_data["test"] == "integration"

    def test_list_objects_in_bucket(self, s3_client, test_bucket, test_file_content):
        """Test listing objects in bucket."""
        # Upload multiple files
        for i in range(3):
            s3_client.put_object(
                Bucket=test_bucket,
                Key=f"test-uploads/file-{i}.txt",
                Body=test_file_content
            )
        
        # List objects
        response = s3_client.list_objects_v2(Bucket=test_bucket, Prefix="test-uploads/")
        assert 'Contents' in response
        assert len(response['Contents']) >= 3

    def test_delete_object_from_s3(self, s3_client, test_bucket, test_file_content):
        """Test deleting object from S3."""
        key = "test-uploads/to-delete.txt"
        
        # Upload
        s3_client.put_object(
            Bucket=test_bucket,
            Key=key,
            Body=test_file_content
        )
        
        # Verify exists
        s3_client.head_object(Bucket=test_bucket, Key=key)
        
        # Delete
        s3_client.delete_object(Bucket=test_bucket, Key=key)
        
        # Verify deleted
        with pytest.raises(ClientError) as exc_info:
            s3_client.head_object(Bucket=test_bucket, Key=key)
        assert exc_info.value.response['Error']['Code'] == '404'


@pytest.mark.integration
class TestFastAPIIntegration:
    """Integration tests for FastAPI endpoints with real S3."""

    @pytest.fixture
    def app_with_test_bucket(self, test_bucket, s3_client):
        """Create app instance with test bucket."""
        import importlib
        
        # Ensure bucket exists (test_bucket fixture should have created it)
        try:
            s3_client.head_bucket(Bucket=test_bucket)
        except ClientError:
            # Create bucket if it doesn't exist
            s3_client.create_bucket(Bucket=test_bucket)
        
        # Set environment variables before importing/reloading app
        original_bucket = os.environ.get('S3_BUCKET_NAME')
        original_endpoint = os.environ.get('S3_ENDPOINT_URL')
        
        os.environ['S3_BUCKET_NAME'] = test_bucket
        os.environ['S3_ENDPOINT_URL'] = S3_ENDPOINT_URL
        
        # Reload app module to pick up new environment variables
        # The get_s3_client() function reads env vars at runtime, so this should work
        import app
        importlib.reload(app)
        
        from fastapi.testclient import TestClient
        
        yield TestClient(app.app)
        
        # Restore original environment
        if original_bucket:
            os.environ['S3_BUCKET_NAME'] = original_bucket
        else:
            os.environ.pop('S3_BUCKET_NAME', None)
        
        if original_endpoint:
            os.environ['S3_ENDPOINT_URL'] = original_endpoint
        else:
            os.environ.pop('S3_ENDPOINT_URL', None)
        
        # Reload app module to restore original state
        importlib.reload(app)

    def test_upload_endpoint_integration(self, app_with_test_bucket, test_file_content, test_bucket, s3_client):
        """Test upload endpoint with real S3."""
        response = app_with_test_bucket.post(
            "/upload",
            files={"file": ("integration-test.txt", test_file_content, "text/plain")}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        
        # Verify file exists in S3
        s3_key = data["key"]
        s3_response = s3_client.head_object(Bucket=test_bucket, Key=s3_key)
        assert s3_response['ContentLength'] == len(test_file_content)

    def test_upload_json_endpoint_integration(self, app_with_test_bucket, test_json_content, test_bucket, s3_client):
        """Test JSON upload endpoint with real S3."""
        response = app_with_test_bucket.post(
            "/upload/json",
            files={"file": ("integration-test.json", test_json_content, "application/json")}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "json_preview" in data
        
        # Verify file exists and is valid JSON
        s3_key = data["key"]
        s3_response = s3_client.get_object(Bucket=test_bucket, Key=s3_key)
        content = s3_response['Body'].read()
        assert content == test_json_content
        
        # Verify JSON structure
        json_data = json.loads(content.decode('utf-8'))
        assert json_data["test"] == "integration"
