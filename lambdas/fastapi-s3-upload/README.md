# FastAPI S3 Upload Lambda

FastAPI-based Lambda function for uploading files to S3 with best practices.

## Features

- **FastAPI** with Mangum adapter for Lambda
- **File upload** endpoint with size validation
- **JSON upload** endpoint with format validation
- **Error handling** with proper HTTP status codes
- **Logging** with structured logs
- **Health checks** for monitoring
- **CORS** support for web applications
- **Environment-based configuration**

## Endpoints

- `GET /` - Health check
- `GET /health` - Detailed health check (checks S3 connectivity)
- `POST /upload` - Upload any file to S3
- `POST /upload/json` - Upload and validate JSON files

## Environment Variables

- `S3_BUCKET_NAME` - Target S3 bucket (default: `scrap-document-poc`)
- `UPLOAD_PREFIX` - S3 prefix for uploads (default: `new/`)
- `S3_ENDPOINT_URL` - S3 endpoint URL (for LocalStack: `http://localstack-us-east-1:4566`)
- `AWS_DEFAULT_REGION` - AWS region (default: `us-east-1`)
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `MAX_FILE_SIZE` - Maximum file size in bytes (default: 10MB)

## Packaging

The Lambda is packaged with dependencies using a Docker-based build or pip install:

```bash
make package-fastapi
```

## Testing

### Unit Tests

Unit tests use mocked S3 client and test all endpoints without requiring S3:

```bash
make test-fastapi-unit
```

### Integration Tests

Integration tests run against LocalStack S3 service:

```bash
# Start LocalStack first
make up-localstack-us-east-1

# Run integration tests
make test-fastapi-integration
```

### Run All Tests

```bash
make test-fastapi-all
```

### Test Structure

- `tests/test_unit.py` - Unit tests with mocked S3
- `tests/test_integration.py` - Integration tests with real S3
- `tests/conftest.py` - Pytest fixtures and configuration
- `pytest.ini` - Pytest configuration

### Test Dependencies

Install test dependencies:
```bash
make install-test-deps-fastapi
```

Or manually:
```bash
cd lambdas/fastapi-s3-upload
pip install -r requirements-test.txt
```

## Best Practices Implemented

1. **Structured Logging** - Uses Python logging module
2. **Error Handling** - Proper HTTP exceptions with meaningful messages
3. **Input Validation** - File size and format validation
4. **Environment Configuration** - All config via environment variables
5. **Health Checks** - Endpoints for monitoring and health checks
6. **Type Hints** - Full type annotations for better code quality
7. **Documentation** - OpenAPI/Swagger docs via FastAPI
8. **Resource Management** - Proper S3 client initialization
9. **Security** - File size limits, content type validation
10. **Observability** - Detailed logging for debugging
11. **Testing** - Comprehensive unit and integration tests
12. **Test Coverage** - Tests cover success and failure scenarios
