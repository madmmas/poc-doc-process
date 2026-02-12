"""
Pytest configuration and fixtures for FastAPI S3 Upload tests.
"""
import os

import boto3
import pytest
from fastapi.testclient import TestClient
from moto import mock_s3

# Set test environment variables before importing app
# Allow override from environment for integration tests
os.environ.setdefault('S3_BUCKET_NAME', 'test-bucket')
os.environ.setdefault('UPLOAD_PREFIX', 'test-uploads/')
os.environ.setdefault('AWS_DEFAULT_REGION', 'us-east-1')
os.environ.setdefault('AWS_ACCESS_KEY_ID', 'test')
os.environ.setdefault('AWS_SECRET_ACCESS_KEY', 'test')
os.environ.setdefault('MAX_FILE_SIZE', '10485760')  # 10MB

from app import app


@pytest.fixture
def client():
    """Create a test client for FastAPI app."""
    return TestClient(app)


@pytest.fixture
def moto_s3():
    """Moto S3 mock context manager for unit tests."""
    with mock_s3():
        yield


@pytest.fixture
def s3_client(moto_s3):
    """Create a real boto3 S3 client that works with moto."""
    return boto3.client('s3', region_name='us-east-1')


@pytest.fixture
def test_bucket(s3_client):
    """Create a test S3 bucket using moto."""
    bucket_name = os.environ.get('S3_BUCKET_NAME', 'test-bucket')
    s3_client.create_bucket(Bucket=bucket_name)
    yield bucket_name
    # Cleanup is handled by moto context manager


@pytest.fixture
def sample_file_content():
    """Sample file content for testing."""
    return b"This is a test file content"


@pytest.fixture
def sample_json_content():
    """Sample JSON content for testing."""
    return b'{"test": "data", "key": "value"}'


@pytest.fixture
def sample_json_file(tmp_path):
    """Create a temporary JSON file for testing."""
    file_path = tmp_path / "test.json"
    file_path.write_text('{"test": "data", "key": "value"}')
    return file_path


@pytest.fixture
def sample_text_file(tmp_path):
    """Create a temporary text file for testing."""
    file_path = tmp_path / "test.txt"
    file_path.write_text("This is a test file")
    return file_path
