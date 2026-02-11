# LocalStack AWS API Gateway + Lambda + DynamoDB Boilerplate

This project demonstrates a simple setup using LocalStack to run AWS Lambda functions through API Gateway with DynamoDB integration, all managed with Terraform. It uses a **modular Docker Compose** layout so you can run LocalStack in one or two regions and optionally PostgreSQL.

## Prerequisites

- Docker and Docker Compose
- Terraform (>= 1.0)
- Python 3.11 (for Lambda function)
- curl (for testing)

## Project Structure

```
.
├── docker-compose.yml      # Base: shared network only (no services)
├── compose/                # Compose overlays (use with -f docker-compose.yml -f compose/<file>)
│   ├── localstack-us-east-1.yml   # LocalStack us-east-1 (port 4566)
│   ├── localstack-us-west-2.yml   # LocalStack us-west-2 (port 4567)
│   └── postgres.yml               # PostgreSQL (port 5432)
├── bootstrap/
│   └── postgres/           # Postgres init scripts (run on first container start)
│       ├── 01-init.sql     # Schema/seed SQL
│       └── README.md       # Init script usage
├── iac/                    # Infrastructure as Code (Terraform)
│   ├── terraform.tf        # Terraform configuration
│   ├── provider.tf         # AWS provider configuration
│   ├── iam.tf              # IAM roles and policies
│   ├── dynamodb.tf         # DynamoDB table
│   ├── lambda.tf           # Lambda functions
│   ├── api_gateway.tf      # API Gateway resources
│   └── outputs.tf          # Terraform outputs
├── lambdas/                # Lambda function code
│   ├── lambda_function.py  # Hello Lambda function
│   └── health_lambda.py    # Health check Lambda function
├── Makefile                # Helper commands (compose, Terraform, test)
├── README.md               # This file
└── .gitignore              # Git ignore rules
```

## Getting Started

### 1. Start LocalStack

The base `docker-compose.yml` only defines a shared network. Start services using a compose overlay.

**Option A – Makefile (recommended)**

```bash
# Start LocalStack us-east-1 only (default for Lambda/API Gateway; port 4566)
make start
# or
make up-localstack-us-east-1

# Optional: start LocalStack us-west-2 (port 4567)
make up-localstack-us-west-2

# Optional: start PostgreSQL (port 5432; uses bootstrap/postgres for init)
make up-postgres

# Start both LocalStack regions
make up-localstack

# Start LocalStack us-east-1 + PostgreSQL (typical dev stack)
make up-all
```

**Option B – Docker Compose directly**

```bash
# LocalStack us-east-1
docker-compose -f docker-compose.yml -f compose/localstack-us-east-1.yml up -d

# LocalStack us-west-2
docker-compose -f docker-compose.yml -f compose/localstack-us-west-2.yml up -d

# PostgreSQL
docker-compose -f docker-compose.yml -f compose/postgres.yml up -d
```

Wait for LocalStack to be ready (us-east-1 on 4566):

```bash
curl http://localhost:4566/_localstack/health
```

Terraform and the API examples below use **us-east-1** (port 4566) by default.

### 2. Package Lambda Functions

Create zip files for both Lambda functions:

```bash
cd lambdas
zip hello_lambda.zip lambda_function.py
zip health_lambda.zip health_lambda.py
```

Or use the Makefile (from project root):

```bash
make package
```

### 3. Initialize Terraform

```bash
cd iac
terraform init
```

Or use the Makefile (from project root):

```bash
make init
```

### 4. Apply Terraform Configuration

```bash
cd iac
terraform apply
```

Or use the Makefile (from project root):

```bash
make apply
```

When prompted, type `yes` to confirm.

### 5. Get the API Gateway URLs

After Terraform completes, it will output the API Gateway URLs. You can also get them with:

```bash
cd iac
terraform output api_gateway_hello_url
terraform output api_gateway_health_url
```

The URLs will look like:
```
http://localhost:4566/restapis/{api-id}/dev/_user_request_/hello
http://localhost:4566/restapis/{api-id}/dev/_user_request_/health
```

### 6. Test the API

Test both endpoints through API Gateway:

```bash
# Test hello endpoint (basic request)
curl http://localhost:4566/restapis/{api-id}/dev/_user_request_/hello

# Test hello endpoint with query parameter
curl "http://localhost:4566/restapis/{api-id}/dev/_user_request_/hello?name=John"

# Test health endpoint (checks DynamoDB connectivity)
curl http://localhost:4566/restapis/{api-id}/dev/_user_request_/health
```

Replace `{api-id}` with the actual API ID from the Terraform output (e.g. `make output`).

Or use the Makefile:

```bash
make test API_ID={api-id}
```

Run `make help` for all available Makefile targets (compose modules, Terraform, test, clean).

## How It Works

1. **LocalStack**: Runs AWS services locally in Docker (Lambda, API Gateway, DynamoDB, IAM). Optional second region (us-west-2) on port 4567.
2. **Lambda Functions**:
   - `hello-lambda`: Returns a greeting message
   - `health-lambda`: Health check endpoint that reads/writes to DynamoDB
3. **API Gateway**: REST API with two endpoints:
   - `/hello`: Triggers the hello Lambda function
   - `/health`: Triggers the health Lambda function
4. **DynamoDB**: Table used by the health check endpoint to verify database connectivity
5. **Terraform**: Manages the infrastructure as code (targets us-east-1 by default)
6. **PostgreSQL** (optional): Standalone Postgres container with init scripts in `bootstrap/postgres/` for schema/seed data

## API Endpoints

### GET /hello
Returns a greeting message. Optional query parameter `name` to customize the greeting.

**Example:**
```bash
curl "http://localhost:4566/restapis/{api-id}/dev/_user_request_/hello?name=John"
```

**Response:**
```json
{
  "message": "Hello, John!",
  "event": {...}
}
```

### GET /health
Health check endpoint that verifies DynamoDB connectivity by writing and reading from the database.

**Example:**
```bash
curl http://localhost:4566/restapis/{api-id}/dev/_user_request_/health
```

**Response (healthy):**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2024-01-01T12:00:00",
  "last_check": "2024-01-01T11:59:00",
  "service": "api-gateway-lambda-dynamodb"
}
```

**Response (unhealthy):**
```json
{
  "status": "unhealthy",
  "error": "error message",
  "service": "api-gateway-lambda-dynamodb"
}
```

## Cleanup

**Terraform**

```bash
cd iac
terraform destroy
```

Or use the Makefile:

```bash
make destroy
```

**Docker Compose (modular)**

```bash
# Stop a specific module
make down-localstack-us-east-1
make down-localstack-us-west-2
make down-postgres

# Stop both LocalStack regions
make down-localstack

# Stop all composed services
make down-all
```

Or with docker-compose (same overlay you used for `up`):

```bash
docker-compose -f docker-compose.yml -f compose/localstack-us-east-1.yml down
docker-compose -f docker-compose.yml -f compose/postgres.yml down -v   # -v removes Postgres data
```

Data volumes: LocalStack uses `.localstack-us-east-1` and `.localstack-us-west-2`; Postgres uses `.postgres`. Remove those directories to wipe persisted data. The Makefile also has `make clean` to remove Lambda zips and Terraform state/plugins.

## Troubleshooting

- **LocalStack not responding**: Check if the container is running with `docker ps`. For us-east-1 use port 4566; for us-west-2 use port 4567.
- **Terraform errors**: Ensure LocalStack us-east-1 is fully started (port 4566) before running Terraform.
- **API Gateway 404**: Verify the API ID in the URL matches the Terraform output (`make output` or `cd iac && terraform output`).
- **Lambda errors**: Check LocalStack logs, e.g. `docker-compose -f docker-compose.yml -f compose/localstack-us-east-1.yml logs localstack-us-east-1`.
- **Postgres init**: Scripts in `bootstrap/postgres/` run only on first start with an empty volume; see `bootstrap/postgres/README.md`.

## Next Steps

- Add more Lambda functions
- Add API Gateway authorizers
- Add more API endpoints
- Integrate with other AWS services (S3, DynamoDB, etc.)
