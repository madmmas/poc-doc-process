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
.PHONY: ssm-llm-local ssm-llm-remote
.PHONY: test-summarize lint-summarize typecheck-summarize check-summarize format-summarize safety-summarize

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
	@echo 'Summarize Document Lambda (dev quality):'
	@echo '  test-summarize            Run unit tests with coverage'
	@echo '  lint-summarize            Run ruff linter and formatter'
	@echo '  typecheck-summarize       Run mypy type checker'
	@echo '  check-summarize           Run lint, typecheck, tests (CI)'
	@echo '  format-summarize          Auto-format with ruff'
	@echo '  safety-summarize          Check deps for vulnerabilities'
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
DIST_DIR := lambdas/dist

package: ## Package Lambda (code + deps) -> lambdas/dist/ (no layer; LocalStack free tier)
	@command -v uv >/dev/null 2>&1 || { echo "uv required: https://docs.astral.sh/uv/getting-started/installation/"; exit 1; }
	@mkdir -p $(DIST_DIR)
	@rm -rf $(DIST_DIR)/summarize_document_build
	@mkdir -p $(DIST_DIR)/summarize_document_build
	cd lambdas/summarize_document && uv pip install aws-lambda-powertools --target ../../$(DIST_DIR)/summarize_document_build
	cp lambdas/summarize_document/summarize_document.py $(DIST_DIR)/summarize_document_build/
	cd $(DIST_DIR)/summarize_document_build && zip -r ../summarize_document.zip .
	@rm -rf $(DIST_DIR)/summarize_document_build

init: ## Initialize Terraform
	cd iac && terraform init

apply: package ## Apply Terraform configuration
	cd iac && terraform apply

destroy: ## Destroy Terraform resources
	cd iac && terraform destroy

output: ## Output all the outputs from Terraform
	cd iac && terraform output

test: ## Test the POC (API Gateway removed; use test-s3-* targets for S3-triggered Lambda)
	@echo "API Gateway was removed. Use: make test-s3-upload (or other test-s3-* targets)"
	@echo "See: make help | grep test"

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

test-s3-invoke: ## Manually invoke summarize_document with S3 event (use if S3/EventBridge trigger did not fire)
	@echo "=== Invoking summarize_document Lambda with S3 event ==="
	@echo "Ensure s3://$(S3_BUCKET)/new/test-success.json exists (e.g. make test-s3-success once)."
	@$(AWS_CLI) lambda invoke \
		--function-name summarize_document \
		--payload fileb://tests/s3-event-payload.json \
		--cli-binary-format raw-in-base64-out \
		/tmp/summarize-document-out.json 2>/dev/null || true
	@echo "Response:"
	@cat /tmp/summarize-document-out.json 2>/dev/null | jq . || cat /tmp/summarize-document-out.json
	@echo ""
	@echo "Check bucket: make test-s3-check"

test-s3-logs: ## Show Lambda function logs for summarize_document
	@echo "=== Lambda Function Logs (summarize_document) ==="
	@echo ""
	@echo "Fetching logs from LocalStack..."
	@$(AWS_CLI) logs tail /aws/lambda/summarize_document --follow 2>/dev/null || \
		echo "Note: Logs may not be available yet. Try: docker logs localstack-us-east-1 | grep summarize"
	@echo ""
	@echo "Alternative: Check LocalStack container logs:"
	@echo "  docker logs localstack-us-east-1 | grep -i summarize"

# ---- Summarize Document Lambda (dev quality) ----
test-summarize: ## Run summarize_document unit tests with coverage
	@echo "=== Summarize Document Lambda Tests ==="
	cd lambdas/summarize_document && uv run pytest -v --cov=. --cov-report=term-missing --cov-report=html

lint-summarize: ## Run ruff linter and formatter check
	@echo "=== Linting summarize_document ==="
	cd lambdas/summarize_document && uv run ruff check . && uv run ruff format --check .

format-summarize: ## Auto-format summarize_document with ruff
	cd lambdas/summarize_document && uv run ruff check . --fix && uv run ruff format .

safety-summarize: ## Check dependencies for known vulnerabilities
	cd lambdas/summarize_document && uv run safety check || true

typecheck-summarize: ## Run mypy type checker
	@echo "=== Type checking summarize_document ==="
	cd lambdas/summarize_document && uv run mypy summarize_document.py

check-summarize: lint-summarize typecheck-summarize test-summarize ## Run lint, typecheck, tests (CI)
	@echo "=== Summarize Document checks passed ==="

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

clean: ## Clean up all generated files
	rm -f lambdas/dist/*.zip
	rm -rf iac/.terraform
	rm -f iac/terraform.tfstate iac/terraform.tfstate.backup
