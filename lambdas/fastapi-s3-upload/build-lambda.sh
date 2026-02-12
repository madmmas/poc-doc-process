#!/bin/bash
# Build Lambda package using Docker for correct architecture

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building FastAPI Lambda package using Docker ==="

# Create a temporary directory for the build
BUILD_DIR=$(mktemp -d)
echo "Build directory: $BUILD_DIR"

# Copy files to build directory
cp app.py "$BUILD_DIR/"
cp requirements.txt "$BUILD_DIR/"

# Use Docker to install dependencies in Linux environment (Lambda runtime)
echo "Installing dependencies in Linux container (Lambda Python 3.11)..."
docker run --rm \
  --platform linux/amd64 \
  --entrypoint /bin/bash \
  -v "$BUILD_DIR:/var/task" \
  -w /var/task \
  public.ecr.aws/lambda/python:3.11 \
  -c "pip install -r requirements.txt -t . --no-cache-dir"

# Verify pydantic_core is installed
if [ ! -d "$BUILD_DIR/pydantic_core" ]; then
  echo "Warning: pydantic_core not found, installing explicitly..."
  docker run --rm \
    --platform linux/amd64 \
    --entrypoint /bin/bash \
    -v "$BUILD_DIR:/var/task" \
    -w /var/task \
    public.ecr.aws/lambda/python:3.11 \
    -c "pip install pydantic-core -t . --no-cache-dir"
fi

# Create zip file in the parent directory (lambdas/)
ZIP_PATH="$SCRIPT_DIR/../fastapi-s3-upload.zip"
cd "$BUILD_DIR"
echo "Creating zip package..."
zip -r "$ZIP_PATH" . \
  -x "*.pyc" "__pycache__/*" "*.dist-info/*" "*.egg-info/*" \
  -x "*.txt" "README.md" "tests/*" "pytest.ini" ".gitignore" \
  -x "Dockerfile" "build-lambda.sh"

# Cleanup
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR"

echo "Lambda package created: $ZIP_PATH"
echo "Package size: $(du -h "$ZIP_PATH" | cut -f1)"
