# Dockerfile for building Lambda package with correct architecture
FROM public.ecr.aws/lambda/python:3.11

# Copy requirements
COPY requirements.txt ${LAMBDA_TASK_ROOT}/

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt -t ${LAMBDA_TASK_ROOT}

# Copy application code
COPY app.py ${LAMBDA_TASK_ROOT}/

# Set handler
CMD [ "app.handler" ]
