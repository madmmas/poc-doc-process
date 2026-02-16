"""Pytest fixtures for summarize_document tests."""

import os

import pytest


@pytest.fixture(autouse=True)
def reset_aws_client_caches():
    """Clear lazy-initialized AWS client caches so each test gets a fresh client under @mock_aws."""
    import summarize_document as mod

    mod._ssm_client = None
    mod._secrets_client = None
    yield


@pytest.fixture(autouse=True)
def set_powertools_env():
    """Set Powertools env vars required for Lambda handler tests."""
    os.environ.setdefault("POWERTOOLS_SERVICE_NAME", "summarize_document")
    os.environ.setdefault("POWERTOOLS_METRICS_NAMESPACE", "PocDocProcess")
    yield
    # Cleanup not needed for env vars in tests


def _s3_event(bucket: str, key: str) -> dict:
    """Build minimal S3 event record."""
    return {
        "Records": [
            {
                "s3": {
                    "bucket": {"name": bucket},
                    "object": {"key": key.replace("/", "%2F") if "%" not in key else key},
                }
            }
        ]
    }


@pytest.fixture
def s3_success_event():
    """S3 event for successful processing."""
    return _s3_event("test-bucket", "new/doc-success.json")


@pytest.fixture
def s3_fail_event():
    """S3 event for failure case."""
    return _s3_event("test-bucket", "new/doc-fail.json")


@pytest.fixture
def s3_skip_event():
    """S3 event for object not in new/ (should skip)."""
    return _s3_event("test-bucket", "processed/doc.json")


@pytest.fixture
def empty_event():
    """Event with no records."""
    return {"Records": []}


@pytest.fixture
def mock_context():
    """Minimal Lambda context."""

    class Context:
        function_name = "summarize_document"
        memory_limit_in_mb = 128
        invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:summarize_document"
        aws_request_id = "test-request-id"
        log_group_name = "/aws/lambda/summarize_document"
        log_stream_name = "2024/01/01/[$LATEST]test"

        @staticmethod
        def get_remaining_time_in_millis() -> int:
            return 300000

    return Context()
