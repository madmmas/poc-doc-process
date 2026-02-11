.PHONY: help start stop restart package init apply destroy test clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start LocalStack
	docker-compose up -d
	@echo "Waiting for LocalStack to be ready..."
	@timeout 30 bash -c 'until curl -s http://localhost:4566/_localstack/health > /dev/null; do sleep 1; done' || true
	@echo "LocalStack is ready!"

stop: ## Stop LocalStack
	docker-compose down

restart: stop start ## Restart LocalStack

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

test: ## Test the API (requires API ID)
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
