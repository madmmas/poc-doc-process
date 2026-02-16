"""Document summarization Lambda - processes S3 uploads and moves to processed/failed."""

from __future__ import annotations

import json
import os
from typing import Any, TypedDict, cast
from urllib.parse import unquote

import boto3
from aws_lambda_powertools import Logger, Metrics

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
SSM_PARAM_LLM_MODE = "/poc-doc-process/summarize-document/llm-mode"
SECRET_ID_OPENAI_API_KEY = "/poc-doc-process/openai-api-key"
VALID_LLM_MODES = ("local", "remote", "bedrock")
PREFIX_NEW = "new/"
PREFIX_PROCESSED = "processed/"
PREFIX_FAILED = "failed/"

# -----------------------------------------------------------------------------
# Logging and metrics
# -----------------------------------------------------------------------------
logger = Logger(service="summarize_document")
metrics = Metrics(namespace="PocDocProcess", service="summarize_document")

# -----------------------------------------------------------------------------
# AWS clients (module-level for reuse across warm Lambda invocations; names
# used by tests for patching). s3_client is set by handler or tests.
# Explicit region avoids NoRegionError when no AWS config (e.g. CI/test collect).
# -----------------------------------------------------------------------------
_DEFAULT_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
ssm_client = boto3.client("ssm", region_name=_DEFAULT_REGION)
secrets_client = boto3.client("secretsmanager", region_name=_DEFAULT_REGION)
s3_client: Any = None


def get_llm_mode() -> str:
    """
    Get the LLM mode from SSM parameter.
    Returns 'local' on error or invalid value.
    """
    llm_mode = "local"
    try:
        response = ssm_client.get_parameter(Name=SSM_PARAM_LLM_MODE)
        value = response["Parameter"]["Value"]
        llm_mode = value if value in VALID_LLM_MODES else "local"
    except Exception as e:
        logger.warning("Error getting LLM mode", extra={"error": str(e)})
    return llm_mode


def get_openai_api_key() -> str | None:
    """
    Get the OpenAI API key from Secrets Manager.
    Returns None on error.
    """
    try:
        response = secrets_client.get_secret_value(SecretId=SECRET_ID_OPENAI_API_KEY)
        return cast(str | None, response.get("SecretString"))
    except Exception as e:
        logger.warning("Error getting secret", extra={"error": str(e)})
        return None


def move_s3_object(s3_client: Any, bucket_name: str, source_key: str, destination_key: str) -> None:
    """
    Move an object from source_key to destination_key by copying and deleting.
    Raises an exception if the object cannot be moved.
    """
    try:
        copy_source = {"Bucket": bucket_name, "Key": source_key}
        s3_client.copy_object(CopySource=copy_source, Bucket=bucket_name, Key=destination_key)
        s3_client.delete_object(Bucket=bucket_name, Key=source_key)
        logger.info("Moved object", extra={"source": source_key, "destination": destination_key})
    except Exception as e:
        logger.error(
            "Error moving object",
            extra={"error": str(e), "source": source_key, "destination": destination_key},
        )
        raise e


def _build_s3_client() -> Any:
    """Build S3 client with optional LocalStack endpoint from env."""
    s3_endpoint = os.environ.get("S3_ENDPOINT_URL")
    config: dict[str, Any] = {
        "region_name": os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
        "aws_access_key_id": os.environ.get("AWS_ACCESS_KEY_ID", "test"),
        "aws_secret_access_key": os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
    }
    if s3_endpoint:
        config["endpoint_url"] = s3_endpoint
    return boto3.client("s3", **config)


def get_s3_client() -> Any:
    """Return module-level s3_client if set (e.g. by tests), otherwise build one."""
    return s3_client if s3_client is not None else _build_s3_client()


# -----------------------------------------------------------------------------
# Handler helpers (short, testable units)
# -----------------------------------------------------------------------------


class FetchedDocument(TypedDict):
    """Result of fetching a document from S3."""

    content_type: str
    content_length: int
    document_data: dict[str, Any]


def parse_s3_record(record: dict[str, Any]) -> tuple[str, str] | None:
    """
    Extract bucket and object key from an S3 event record.
    Returns (bucket_name, object_key) if the object is in PREFIX_NEW, else None.
    """
    try:
        bucket_name = record["s3"]["bucket"]["name"]
        object_key = unquote(record["s3"]["object"]["key"])
    except (KeyError, TypeError):
        return None
    if not object_key.startswith(PREFIX_NEW):
        return None
    return (bucket_name, object_key)


def fetch_document(
    s3_client: Any,
    bucket_name: str,
    object_key: str,
) -> FetchedDocument:
    """
    Head + get object from S3 and parse as JSON.
    Raises on S3 or JSON errors.
    """
    response = s3_client.head_object(Bucket=bucket_name, Key=object_key)
    content_type = response.get("ContentType", "unknown")
    content_length = response.get("ContentLength", 0)

    obj_response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
    json_content = obj_response["Body"].read().decode("utf-8")
    document_data = json.loads(json_content)

    return FetchedDocument(
        content_type=content_type,
        content_length=content_length,
        document_data=document_data,
    )


def should_process_successfully(document_data: dict[str, Any]) -> bool:
    """True if document should be considered processed successfully (no simulated failure)."""
    return not document_data.get("should_fail", False)


def process_record(
    s3_client: Any,
    bucket_name: str,
    object_key: str,
    llm_mode: str,
) -> dict[str, Any]:
    """
    Process a single S3 object: fetch, decide outcome, move to processed/ or failed/.
    Returns a response dict with statusCode and body (for Lambda).
    """
    try:
        doc = fetch_document(s3_client, bucket_name, object_key)
    except Exception as e:
        error_msg = f"Error processing document {object_key}: {str(e)}"
        logger.error("Processing failed", extra={"object_key": object_key, "error": str(e)})
        move_err = _move_to_failed_and_log(s3_client, bucket_name, object_key)
        if move_err:
            error_msg += f" | Failed to move document: {move_err}"
        return _error_response(error_msg, object_key)

    content_type = doc["content_type"]
    content_length = doc["content_length"]
    document_data = doc["document_data"]

    logger.debug(
        "Document metadata",
        extra={
            "bucket": bucket_name,
            "key": object_key,
            "content_type": content_type,
            "size_bytes": content_length,
        },
    )
    logger.debug(
        "Processing decision",
        extra={
            "should_fail": document_data.get("should_fail", False),
            "processing_successful": should_process_successfully(document_data),
        },
    )

    if should_process_successfully(document_data):
        filename = object_key.replace(PREFIX_NEW, "", 1)
        destination_key = f"{PREFIX_PROCESSED}{filename}"
        move_s3_object(s3_client, bucket_name, object_key, destination_key)
        summary = {
            "status": "success",
            "bucket": bucket_name,
            "original_key": object_key,
            "new_location": destination_key,
            "content_type": content_type,
            "size_bytes": content_length,
            "llm_mode": llm_mode,
            "message": "Document processed successfully and moved to processed folder.",
        }
        logger.info("Document processed successfully", extra={"destination": destination_key})
        return _success_response(summary)

    # Simulated or real processing failure
    error_msg = "Document processing failed"
    move_err = _move_to_failed_and_log(s3_client, bucket_name, object_key)
    if move_err:
        error_msg += f" | Failed to move document: {move_err}"
    return _error_response(error_msg, object_key)


def _move_to_failed_and_log(
    s3_client: Any,
    bucket_name: str,
    object_key: str,
) -> str | None:
    """Move object to failed/. Returns error message if move failed, else None."""
    try:
        filename = object_key.replace(PREFIX_NEW, "", 1)
        destination_key = f"{PREFIX_FAILED}{filename}"
        move_s3_object(s3_client, bucket_name, object_key, destination_key)
        logger.info(
            "Moved failed document to failed folder",
            extra={"destination": destination_key},
        )
        return None
    except Exception as move_error:
        logger.exception("Critical: could not move document to failed folder")
        return str(move_error)


def _success_response(summary: dict[str, Any]) -> dict[str, Any]:
    """Build Lambda success response."""
    return {"statusCode": 200, "body": json.dumps(summary)}


def _error_response(message: str, object_key: str) -> dict[str, Any]:
    """Build Lambda error response."""
    return {
        "statusCode": 500,
        "body": json.dumps(
            {
                "status": "error",
                "message": message,
                "original_key": object_key,
            }
        ),
    }


def _no_records_response() -> dict[str, Any]:
    """Build Lambda response when there are no records to process."""
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "No records to process"}),
    }


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Lambda function triggered by S3 object creation events in the "new/" folder.
    Processes uploaded documents and moves them to "processed/" on success or "failed/" on failure.
    """
    llm_mode = get_llm_mode()
    logger.info("LLM mode", extra={"llm_mode": llm_mode})

    if llm_mode == "remote":
        openai_api_key = get_openai_api_key()
        logger.info("OpenAI API key configured", extra={"configured": openai_api_key is not None})

    s3_client = get_s3_client()

    for record in event.get("Records", []):
        parsed = parse_s3_record(record)
        if parsed is None:
            try:
                bucket_name = record["s3"]["bucket"]["name"]
                object_key = unquote(record["s3"]["object"]["key"])
            except (KeyError, TypeError):
                pass
            else:
                logger.warning(
                    "Object not in new folder, skipping",
                    extra={"object_key": object_key, "bucket": bucket_name},
                )
            continue

        bucket_name, object_key = parsed
        logger.info("Processing document", extra={"bucket": bucket_name, "key": object_key})

        result = process_record(s3_client, bucket_name, object_key, llm_mode)
        return result

    return _no_records_response()
