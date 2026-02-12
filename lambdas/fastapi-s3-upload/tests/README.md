# FastAPI S3 Upload Lambda - Test Suite

Comprehensive test suite for the FastAPI S3 Upload Lambda function.

## Test Structure

```
tests/
├── __init__.py           # Package marker
├── conftest.py           # Pytest fixtures and configuration
├── test_unit.py          # Unit tests (mocked S3)
└── test_integration.py   # Integration tests (real S3)
```

## Running Tests

### Unit Tests Only

Unit tests use mocked S3 client and don't require any external services:

```bash
make test-fastapi-unit
```

Or directly:
```bash
cd lambdas/fastapi-s3-upload
pytest tests/test_unit.py -v
```

### Integration Tests

Integration tests require LocalStack S3 service to be running:

```bash
# Start LocalStack first
make up-localstack-us-east-1

# Run integration tests
make test-fastapi-integration
```

Or directly:
```bash
cd lambdas/fastapi-s3-upload
S3_ENDPOINT_URL=http://localhost:4566 pytest tests/test_integration.py -v -m integration
```

### All Tests

Run both unit and integration tests:

```bash
make test-fastapi-all
```

## Test Coverage

### Unit Tests (`test_unit.py`)

Uses **moto** for realistic AWS S3 mocking:
- ✅ Root endpoint health check
- ✅ Health endpoint (success and failure cases)
- ✅ File upload endpoint (success with real S3 verification)
- ✅ File upload with folder parameter
- ✅ Empty file validation
- ✅ File size limit validation
- ✅ S3 error handling
- ✅ JSON upload endpoint (success with real S3 verification)
- ✅ Invalid JSON format validation
- ✅ JSON file extension handling
- ✅ Large JSON file validation
- ✅ Lambda handler integration

**Benefits of using moto:**
- More realistic AWS service behavior
- Actual S3 operations work (get_object, head_object, etc.)
- Easier to test - no need to mock individual methods
- Can verify files were actually uploaded

### Integration Tests (`test_integration.py`)

- ✅ S3 bucket creation and access
- ✅ Direct S3 file upload
- ✅ Direct S3 JSON upload and retrieval
- ✅ S3 object listing
- ✅ S3 object deletion
- ✅ FastAPI upload endpoint with real S3
- ✅ FastAPI JSON upload endpoint with real S3

## Test Fixtures

### Unit Test Fixtures (`conftest.py`)

- `client` - FastAPI TestClient instance
- `moto_s3` - Moto S3 mock context manager
- `s3_client` - Real boto3 S3 client (works with moto)
- `test_bucket` - Test S3 bucket created with moto
- `sample_file_content` - Sample binary file content
- `sample_json_content` - Sample JSON content
- `sample_json_file` - Temporary JSON file
- `sample_text_file` - Temporary text file

### Integration Test Fixtures (`test_integration.py`)

- `s3_client` - Real boto3 S3 client (LocalStack)
- `test_bucket` - Temporary test bucket (created/cleaned up automatically)
- `test_file_content` - Test file content
- `test_json_content` - Test JSON content
- `app_with_test_bucket` - FastAPI app configured with test bucket

## Test Markers

Tests are marked with pytest markers:

- `@pytest.mark.integration` - Integration tests (require LocalStack)
- Unit tests have no marker (run by default)

Run only unit tests:
```bash
pytest -m "not integration"
```

Run only integration tests:
```bash
pytest -m integration
```

## Environment Variables

### Unit Tests

Unit tests use default test values set in `conftest.py`:
- `S3_BUCKET_NAME=test-bucket`
- `UPLOAD_PREFIX=test-uploads/`
- `AWS_DEFAULT_REGION=us-east-1`
- `MAX_FILE_SIZE=10485760` (10MB)

### Integration Tests

Integration tests can override via environment:
- `S3_ENDPOINT_URL` - LocalStack endpoint (default: `http://localhost:4566`)
- `S3_BUCKET_NAME` - Test bucket name (default: `test-integration-bucket`)
- `AWS_DEFAULT_REGION` - AWS region (default: `us-east-1`)

## Dependencies

Test dependencies are in `requirements-test.txt`:
- `pytest` - Testing framework
- `pytest-asyncio` - Async test support
- `pytest-cov` - Coverage reporting
- `httpx` - HTTP client (used by FastAPI TestClient)
- `moto[s3]` - AWS service mocking library (replaces unittest.mock)

Install with:
```bash
make install-test-deps-fastapi
```

## Best Practices

1. **Isolation** - Each test is independent
2. **Mocking** - Unit tests use mocked S3 client
3. **Real Services** - Integration tests use LocalStack S3
4. **Cleanup** - Integration tests clean up created resources
5. **Fixtures** - Reusable test fixtures for common setup
6. **Markers** - Tests marked for selective execution
7. **Error Cases** - Both success and failure scenarios tested
8. **Validation** - Input validation thoroughly tested

## Continuous Integration

Tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run unit tests
  run: make test-fastapi-unit

- name: Start LocalStack
  run: make up-localstack-us-east-1

- name: Run integration tests
  run: make test-fastapi-integration
```

## Troubleshooting

### Integration tests fail with connection errors

- Ensure LocalStack is running: `make up-localstack-us-east-1`
- Check S3 service is available: `curl http://localhost:4566/_localstack/health`
- Verify endpoint URL: `S3_ENDPOINT_URL=http://localhost:4566`

### Tests fail with import errors

- Install test dependencies: `make install-test-deps-fastapi`
- Ensure you're in the correct directory: `cd lambdas/fastapi-s3-upload`

### Mock not working in unit tests

- Ensure `@mock_s3` decorator is applied to test methods
- Check that moto is installed: `pip install moto[s3]`
- Verify bucket is created before testing: `s3_client.create_bucket(Bucket='test-bucket')`
