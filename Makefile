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

clean: ## Clean up generated files
	rm -f lambdas/*.zip
	rm -rf iac/.terraform
	rm -f iac/terraform.tfstate iac/terraform.tfstate.backup
