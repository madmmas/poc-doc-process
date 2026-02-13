"""Pytest tests for summarize_document lambda."""

import json
from unittest.mock import patch

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_aws

from summarize_document import get_llm_mode, get_openai_api_key, lambda_handler, move_s3_object

SSM_PARAM_NAME = "/poc-doc-process/summarize-document/llm-mode"
SECRET_NAME = "poc-doc-process/openai-api-key"
BUCKET = "test-bucket"


class TestGetLlmMode:
    """Tests for get_llm_mode() using moto."""

    @mock_aws
    def test_returns_local_when_ssm_returns_local(self):
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="local", Type="String")
        assert get_llm_mode() == "local"

    @mock_aws
    def test_returns_remote_when_ssm_returns_remote(self):
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="remote", Type="String")
        assert get_llm_mode() == "remote"

    @mock_aws
    def test_returns_bedrock_when_ssm_returns_bedrock(self):
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="bedrock", Type="String")
        assert get_llm_mode() == "bedrock"

    @mock_aws
    def test_returns_local_when_ssm_returns_invalid_value(self):
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="invalid", Type="String")
        assert get_llm_mode() == "local"

    @mock_aws
    def test_returns_local_when_value_is_empty_string(self):
        # SSM PutParameter rejects Value=""; patch get_parameter to simulate empty value
        with patch(
            "summarize_document.ssm_client.get_parameter",
            return_value={"Parameter": {"Name": SSM_PARAM_NAME, "Value": "", "Type": "String"}},
        ):
            assert get_llm_mode() == "local"

    @mock_aws
    def test_returns_local_when_parameter_does_not_exist(self):
        assert get_llm_mode() == "local"


class TestGetOpenaiApiKey:
    """Tests for get_openai_api_key() using moto."""

    @mock_aws
    def test_returns_secret_string_on_success(self):
        sm = boto3.client("secretsmanager", region_name="us-east-1")
        # Use same SecretId as lambda: get_secret_value(SecretId="/poc-doc-process/openai-api-key")
        sm.create_secret(Name="/poc-doc-process/openai-api-key", SecretString="sk-test-key-123")
        with patch("summarize_document.secrets_client", sm):
            assert get_openai_api_key() == "sk-test-key-123"

    @mock_aws
    def test_returns_empty_string_when_secret_is_empty(self):
        # AWS rejects SecretString=""; mock get_secret_value to return empty string
        with patch(
            "summarize_document.secrets_client.get_secret_value",
            return_value={"SecretString": ""},
        ):
            assert get_openai_api_key() == ""

    @mock_aws
    def test_returns_none_when_secret_does_not_exist(self):
        assert get_openai_api_key() is None


class TestMoveS3Object:
    """Tests for move_s3_object() using moto."""

    @mock_aws
    def test_moves_object_from_source_to_destination(self):
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET)
        s3.put_object(Bucket=BUCKET, Key="new/doc.json", Body=b'{"test": true}')
        move_s3_object(s3, BUCKET, "new/doc.json", "processed/doc.json")
        # Source should be gone
        with pytest.raises(ClientError):
            s3.head_object(Bucket=BUCKET, Key="new/doc.json")
        # Destination should exist
        r = s3.get_object(Bucket=BUCKET, Key="processed/doc.json")
        assert r["Body"].read() == b'{"test": true}'

    @mock_aws
    def test_raises_when_source_does_not_exist(self):
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET)
        with pytest.raises(ClientError):
            move_s3_object(s3, BUCKET, "new/nonexistent.json", "processed/nonexistent.json")


class TestLambdaHandler:
    """Tests for lambda_handler() using moto."""

    @mock_aws
    def test_success_moves_to_processed(self, mock_context):
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET)
        doc = {"title": "Test", "should_fail": False}
        s3.put_object(
            Bucket=BUCKET,
            Key="new/doc-success.json",
            Body=json.dumps(doc).encode(),
            ContentType="application/json",
        )
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="local", Type="String")
        event = {
            "Records": [
                {
                    "s3": {
                        "bucket": {"name": BUCKET},
                        "object": {"key": "new%2Fdoc-success.json"},
                    }
                }
            ]
        }

        with patch("summarize_document.s3_client", s3):
            result = lambda_handler(event, mock_context)

        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert body["status"] == "success"
        assert body["new_location"] == "processed/doc-success.json"
        with pytest.raises(ClientError):
            s3.head_object(Bucket=BUCKET, Key="new/doc-success.json")
        s3.head_object(Bucket=BUCKET, Key="processed/doc-success.json")

    @mock_aws
    def test_failure_moves_to_failed(self, mock_context):
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET)
        doc = {"title": "Test", "should_fail": True}
        s3.put_object(
            Bucket=BUCKET,
            Key="new/doc-fail.json",
            Body=json.dumps(doc).encode(),
            ContentType="application/json",
        )
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="local", Type="String")
        event = {
            "Records": [
                {
                    "s3": {
                        "bucket": {"name": BUCKET},
                        "object": {"key": "new%2Fdoc-fail.json"},
                    }
                }
            ]
        }

        with patch("summarize_document.s3_client", s3):
            result = lambda_handler(event, mock_context)

        assert result["statusCode"] == 500
        body = json.loads(result["body"])
        assert body["status"] == "error"
        assert "doc-fail.json" in body["original_key"]
        s3.head_object(Bucket=BUCKET, Key="failed/doc-fail.json")

    @mock_aws
    def test_skips_object_not_in_new_folder(self, mock_context):
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET)
        s3.put_object(Bucket=BUCKET, Key="processed/doc.json", Body=b"{}")
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="local", Type="String")
        event = {
            "Records": [
                {
                    "s3": {
                        "bucket": {"name": BUCKET},
                        "object": {"key": "processed%2Fdoc.json"},
                    }
                }
            ]
        }

        with patch("summarize_document.s3_client", s3):
            result = lambda_handler(event, mock_context)

        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert body["message"] == "No records to process"

    @mock_aws
    def test_empty_records_returns_no_records_message(self, empty_event, mock_context):
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(Name=SSM_PARAM_NAME, Value="local", Type="String")
        result = lambda_handler(empty_event, mock_context)
        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert body["message"] == "No records to process"
