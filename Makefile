# Compose base + module overlay. Compose files are in root and compose/
COMPOSE_BASE  := -f docker-compose.yml
COMPOSE_LS_E1 := $(COMPOSE_BASE) -f compose/localstack-us-east-1.yml
COMPOSE_LS_W2 := $(COMPOSE_BASE) -f compose/localstack-us-west-2.yml
COMPOSE_PG    := $(COMPOSE_BASE) -f compose/postgres.yml

.PHONY: help start stop restart
.PHONY: up-localstack-us-east-1 down-localstack-us-east-1
.PHONY: up-localstack-us-west-2 down-localstack-us-west-2
.PHONY: up-postgres down-postgres
.PHONY: up-localstack down-localstack up-all down-all
.PHONY: package init apply destroy test clean output open-localstack open-localstack-w2
.PHONY: test-s3 test-s3-success test-s3-fail test-s3-check test-s3-logs test-s3-clean
.PHONY: ssm-llm-local ssm-llm-remote

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Docker Compose (modular):'
	@echo '  up-localstack-us-east-1   Start LocalStack us-east-1 (port 4566)'
	@echo '  up-localstack-us-west-2   Start LocalStack us-west-2 (port 4567)'
	@echo '  up-postgres               Start PostgreSQL (port 5432)'
	@echo '  up-localstack             Start both LocalStack regions'
	@echo '  up-all                    Start LocalStack us-east-1 + Postgres'
	@echo '  down-<module>            Stop a module (e.g. down-postgres)'
	@echo '  down-all                  Stop all composed services'
	@echo ''
	@echo 'S3 & Lambda Tests:'
	@echo '  test-s3                   Run both success and failure S3 tests'
	@echo '  test-s3-success           Test successful document processing'
	@echo '  test-s3-fail               Test failed document processing'
	@echo '  test-s3-check             Check S3 bucket contents'
	@echo '  test-s3-logs              Show Lambda function logs'
	@echo '  test-s3-clean             Clean up test files from S3'
	@echo ''
	@echo 'SSM (summarize_document LLM mode):'
	@echo '  ssm-llm-local             Set LLM mode to local'
	@echo '  ssm-llm-remote            Set LLM mode to remote'
	@echo ''
	@echo 'FastAPI Lambda Tests:'
	@echo '  test-fastapi-unit         Run FastAPI unit tests (mocked S3)'
	@echo '  test-fastapi-integration  Run FastAPI integration tests (requires LocalStack)'
	@echo '  test-fastapi-all          Run all FastAPI tests'
	@echo '  install-test-deps-fastapi Install test dependencies'
	@echo ''
	@echo 'FastAPI Lambda Packaging:'
	@echo '  package-fastapi-docker   Package using Docker (recommended)'
	@echo '  clean-fastapi             Clean installed dependencies from source'
	@echo ''
	@echo 'Admin Web App:'
	@echo '  install-admin-web         Install admin web dependencies'
	@echo '  dev-admin-web             Start admin web dev server'
	@echo '  build-admin-web            Build admin web for production'
	@echo '  deploy-admin-web           Deploy admin web to S3'
	@echo ''
	@echo 'Legacy / convenience:'
	@echo '  start                     Same as up-localstack-us-east-1'
	@echo '  stop                      Same as down-localstack-us-east-1'
	@echo '  open-localstack           Open LocalStack us-east-1 in browser'
	@echo '  open-localstack-w2        Open LocalStack us-west-2 in browser'
	@echo ''
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-25s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ---- LocalStack us-east-1 ----
up-localstack-us-east-1: ## Start LocalStack us-east-1
	docker-compose $(COMPOSE_LS_E1) up -d
	@echo "Waiting for LocalStack (us-east-1) on :4566..."
	@timeout 30 bash -c 'until curl -s http://localhost:4566/_localstack/health > /dev/null; do sleep 1; done' || true
	@echo "LocalStack us-east-1 is ready."

down-localstack-us-east-1: ## Stop LocalStack us-east-1
	docker-compose $(COMPOSE_LS_E1) down

# ---- LocalStack us-west-2 ----
up-localstack-us-west-2: ## Start LocalStack us-west-2
	docker-compose $(COMPOSE_LS_W2) up -d
	@echo "Waiting for LocalStack (us-west-2) on :4567..."
	@timeout 30 bash -c 'until curl -s http://localhost:4567/_localstack/health > /dev/null; do sleep 1; done' || true
	@echo "LocalStack us-west-2 is ready."

down-localstack-us-west-2: ## Stop LocalStack us-west-2
	docker-compose $(COMPOSE_LS_W2) down

# ---- Postgres ----
up-postgres: ## Start PostgreSQL
	docker-compose $(COMPOSE_PG) up -d
	@echo "PostgreSQL is up on :5432 (user=postgres, password=postgres, db=postgres)."

down-postgres: ## Stop PostgreSQL
	docker-compose $(COMPOSE_PG) down

# ---- Combined ----
up-localstack: up-localstack-us-east-1 up-localstack-us-west-2 ## Start both LocalStack regions

down-localstack: down-localstack-us-east-1 down-localstack-us-west-2 ## Stop both LocalStack regions

up-all: up-localstack-us-east-1 up-postgres ## Start LocalStack us-east-1 + Postgres (typical dev stack)

down-all: down-localstack-us-east-1 down-localstack-us-west-2 down-postgres ## Stop all modules
	docker-compose $(COMPOSE_BASE) down 2>/dev/null || true

# ---- Legacy (default: LocalStack us-east-1 only) ----
start: up-localstack-us-east-1 ## Start LocalStack (us-east-1)

stop: down-localstack-us-east-1 ## Stop LocalStack (us-east-1)

restart: stop start ## Restart LocalStack us-east-1

# ---- Open in browser (open on macOS, xdg-open on Linux) ----
OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

open-localstack: ## Open LocalStack us-east-1 in browser
	$(OPEN_CMD) http://localhost:4566

open-localstack-w2: ## Open LocalStack us-west-2 in browser
	$(OPEN_CMD) http://localhost:4567

# ---- Lambda / Terraform ----
package: ## Package Lambda functions
	cd lambdas && zip -r hello_lambda.zip lambda_function.py
	cd lambdas && zip -r health_lambda.zip health_lambda.py
	cd lambdas && zip -r summarize_document.zip summarize_document.py

init: ## Initialize Terraform
	cd iac && terraform init

apply: package ## Apply Terraform configuration
	cd iac && terraform apply

destroy: ## Destroy Terraform resources
	cd iac && terraform destroy

output: ## Output all the outputs from Terraform
	cd iac && terraform output

test: ## Test the API (requires API_ID)
	@echo "Usage: make test API_ID=<your-api-id>"
	@if [ -z "$(API_ID)" ]; then \
		echo "Error: API_ID is required"; \
		echo "Get it from: cd iac && terraform output api_gateway_hello_url"; \
		exit 1; \
	fi
	@echo "Testing /hello endpoint:"
	curl "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/hello"
	@echo ""
	@echo ""
	@echo "Testing /hello endpoint with name parameter:"
	curl "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/hello?name=John"
	@echo ""
	@echo ""
	@echo "Testing /health endpoint:"
	curl "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/health"
	@echo ""

# ---- S3 Tests ----
S3_BUCKET := scrap-document-poc
S3_ENDPOINT := http://localhost:4566
AWS_CLI := aws --endpoint-url $(S3_ENDPOINT) --region us-east-1

test-s3-check: ## Check S3 bucket contents and structure
	@echo "=== Checking S3 Bucket: $(S3_BUCKET) ==="
	@echo ""
	@echo "Bucket exists check:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/ 2>/dev/null || echo "Bucket does not exist or is empty"
	@echo ""
	@echo "Contents of 'new/' folder:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/new/ 2>/dev/null || echo "  (empty)"
	@echo ""
	@echo "Contents of 'processed/' folder:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/processed/ 2>/dev/null || echo "  (empty)"
	@echo ""
	@echo "Contents of 'failed/' folder:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/failed/ 2>/dev/null || echo "  (empty)"
	@echo ""

test-s3-success: ## Test S3 Lambda trigger with success case (moves to processed/)
	@echo "=== Testing S3 Lambda Trigger - Success Case ==="
	@echo ""
	@echo "1. Uploading test-success.json to s3://$(S3_BUCKET)/new/"
	@$(AWS_CLI) s3 cp tests/test-success.json s3://$(S3_BUCKET)/new/test-success.json
	@echo ""
	@echo "2. Waiting 5 seconds for Lambda to process..."
	@sleep 5
	@echo ""
	@echo "3. Checking results:"
	@echo "   - File should be removed from 'new/' folder"
	@echo "   - File should appear in 'processed/' folder"
	@echo ""
	@echo "Contents of 'new/' folder:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/new/ 2>/dev/null || echo "  (empty - good!)"
	@echo ""
	@echo "Contents of 'processed/' folder:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/processed/ 2>/dev/null || echo "  (empty - Lambda may not have triggered yet)"
	@echo ""
	@echo "=== Success test complete. Check Lambda logs with: make test-s3-logs ==="

test-s3-fail: ## Test S3 Lambda trigger with failure case (moves to failed/)
	@echo "=== Testing S3 Lambda Trigger - Failure Case ==="
	@echo ""
	@echo "1. Uploading test-fail.json to s3://$(S3_BUCKET)/new/"
	@$(AWS_CLI) s3 cp tests/test-fail.json s3://$(S3_BUCKET)/new/test-fail.json
	@echo ""
	@echo "2. Waiting 5 seconds for Lambda to process..."
	@sleep 5
	@echo ""
	@echo "3. Checking results:"
	@echo "   - File should be removed from 'new/' folder"
	@echo "   - File should appear in 'failed/' folder"
	@echo ""
	@echo "Contents of 'new/' folder:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/new/ 2>/dev/null || echo "  (empty - good!)"
	@echo ""
	@echo "Contents of 'failed/' folder:"
	@$(AWS_CLI) s3 ls s3://$(S3_BUCKET)/failed/ 2>/dev/null || echo "  (empty - Lambda may not have triggered yet)"
	@echo ""
	@echo "=== Failure test complete. Check Lambda logs with: make test-s3-logs ==="

test-s3: test-s3-success test-s3-fail ## Run both S3 success and failure tests
	@echo ""
	@echo "=== All S3 tests complete ==="
	@echo "Run 'make test-s3-check' to see final bucket state"

test-s3-logs: ## Show Lambda function logs for summarize_document
	@echo "=== Lambda Function Logs (summarize_document) ==="
	@echo ""
	@echo "Fetching logs from LocalStack..."
	@$(AWS_CLI) logs tail /aws/lambda/summarize_document --follow 2>/dev/null || \
		echo "Note: Logs may not be available yet. Try: docker logs localstack-us-east-1 | grep summarize"
	@echo ""
	@echo "Alternative: Check LocalStack container logs:"
	@echo "  docker logs localstack-us-east-1 | grep -i summarize"

test-s3-clean: ## Clean up test files from S3 bucket
	@echo "=== Cleaning up test files from S3 ==="
	@echo "Removing test files from all folders..."
	@$(AWS_CLI) s3 rm s3://$(S3_BUCKET)/new/test-success.json 2>/dev/null || true
	@$(AWS_CLI) s3 rm s3://$(S3_BUCKET)/new/test-fail.json 2>/dev/null || true
	@$(AWS_CLI) s3 rm s3://$(S3_BUCKET)/processed/test-success.json 2>/dev/null || true
	@$(AWS_CLI) s3 rm s3://$(S3_BUCKET)/processed/test-fail.json 2>/dev/null || true
	@$(AWS_CLI) s3 rm s3://$(S3_BUCKET)/failed/test-success.json 2>/dev/null || true
	@$(AWS_CLI) s3 rm s3://$(S3_BUCKET)/failed/test-fail.json 2>/dev/null || true
	@echo "Cleanup complete!"

# ---- SSM (summarize_document LLM mode) ----
SSM_LLM_PARAM := /poc-doc-process/summarize-document/llm-mode

ssm-llm-local: ## Set summarize_document LLM mode to local
	@$(AWS_CLI) ssm put-parameter --name "$(SSM_LLM_PARAM)" --value "local" --type String --overwrite
	@echo "SSM parameter $(SSM_LLM_PARAM) set to: local"
	@echo "Redeploy Lambda (make apply) for env to take effect in Terraform-managed Lambda."

ssm-llm-remote: ## Set summarize_document LLM mode to remote
	@$(AWS_CLI) ssm put-parameter --name "$(SSM_LLM_PARAM)" --value "remote" --type String --overwrite
	@echo "SSM parameter $(SSM_LLM_PARAM) set to: remote"
	@echo "Redeploy Lambda (make apply) for env to take effect in Terraform-managed Lambda."

test-fastapi: ## Test FastAPI Lambda endpoints (requires API_ID)
	@echo "Usage: make test-fastapi API_ID=<your-api-id>"
	@if [ -z "$(API_ID)" ]; then \
		echo "Error: API_ID is required"; \
		echo "Get it from: cd iac && terraform output api_gateway_id"; \
		exit 1; \
	fi
	@echo "=== Testing FastAPI Lambda endpoints ==="
	@echo ""
	@echo "1. Root endpoint (health check):"
	@curl -s "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/" | jq . || echo "Failed"
	@echo ""
	@echo "2. Health endpoint:"
	@curl -s "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/health" | jq . || echo "Failed"
	@echo ""
	@echo "3. Upload JSON file:"
	@curl -X POST "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/upload/json" \
		-F "file=@tests/test-success.json" | jq . || echo "Failed"
	@echo ""
	@echo "4. Upload regular file:"
	@curl -X POST "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/upload" \
		-F "file=@tests/test-success.json" | jq . || echo "Failed"
	@echo ""
	@echo "=== FastAPI tests complete ==="

# ---- Admin Web App ----
ADMIN_WEB_BUCKET := admin-web-poc
ADMIN_WEB_DIR := admin-web

install-admin-web: ## Install admin web dependencies
	@echo "=== Installing Admin Web dependencies ==="
	cd $(ADMIN_WEB_DIR) && npm install

dev-admin-web: ## Start admin web development server
	@echo "=== Starting Admin Web dev server ==="
	cd $(ADMIN_WEB_DIR) && npm run dev

build-admin-web: ## Build admin web for production
	@echo "=== Building Admin Web ==="
	cd $(ADMIN_WEB_DIR) && npm run build

deploy-admin-web: build-admin-web ## Deploy admin web to S3
	@echo "=== Deploying Admin Web to S3 ==="
	@echo "Bucket: $(ADMIN_WEB_BUCKET)"
	@echo "Note: Ensure bucket exists and static website hosting is enabled"
	aws s3 sync $(ADMIN_WEB_DIR)/out/ s3://$(ADMIN_WEB_BUCKET)/ --delete --endpoint-url http://localhost:4566 || \
		echo "Deployment failed. Check bucket exists and AWS credentials."

clean-fastapi: ## Clean up installed dependencies from fastapi-s3-upload directory
	@echo "=== Cleaning FastAPI Lambda source directory ==="
	cd lambdas/fastapi-s3-upload && \
		rm -rf __pycache__ .pytest_cache .coverage htmlcov && \
		rm -rf *.egg-info *.dist-info bin/ && \
		rm -rf annotated_types anyio boto3 botocore dateutil fastapi idna jmespath mangum multipart pydantic pydantic_core s3transfer sniffio starlette typing_inspection urllib3 && \
		rm -f six.py typing_extensions.py && \
		echo "FastAPI source directory cleaned"

clean: clean-fastapi ## Clean up all generated files
	rm -f lambdas/*.zip
	rm -rf iac/.terraform
	rm -f iac/terraform.tfstate iac/terraform.tfstate.backup
