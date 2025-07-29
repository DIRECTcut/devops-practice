# Lambda Nginx Monitoring Makefile
.PHONY: help init validate plan apply destroy clean output logs test-lambda package

# Default target
help:
	@echo "Available targets:"
	@echo "  make init      - Initialize Terraform"
	@echo "  make validate  - Validate Terraform configuration"
	@echo "  make plan      - Show deployment plan"
	@echo "  make apply     - Deploy infrastructure"
	@echo "  make destroy   - Destroy infrastructure"
	@echo "  make output    - Show outputs"
	@echo "  make logs      - View Lambda logs (last 10 minutes)"
	@echo "  make test-lambda - Manually invoke Lambda function"
	@echo "  make package   - Create Lambda deployment package"
	@echo "  make clean     - Clean Terraform files"

# Initialize Terraform
init:
	terraform init

# Validate configuration
validate: init
	terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive

# Check formatting and validation
check: fmt validate
	@echo "✓ Configuration is valid and properly formatted"

# Show deployment plan
plan_dry: validate
	terraform plan

plan: validate
	terraform plan -out tfplan

# Apply configuration
apply: validate
	terraform apply

# Destroy infrastructure
destroy:
	terraform destroy

# Show outputs
output:
	@echo "=== Lambda Function Details ==="
	@terraform output -raw check_web_name
	@echo ""
	@echo "=== CloudWatch Log Group ==="
	@terraform output -raw cloudwatch_log_group
	@echo ""
	@echo "=== Secret Name ==="
	@terraform output -raw secret_name
	@echo ""
	@echo "=== Monitoring Schedule ==="
	@terraform output -raw monitoring_schedule

# View Lambda logs (requires AWS CLI)
logs:
	@echo "Fetching Lambda logs from the last 10 minutes..."
	@aws logs filter-log-events \
		--log-group-name "$$(terraform output -raw cloudwatch_log_group)" \
		--start-time $$(date -d '10 minutes ago' +%s)000 \
		--query 'events[*].[timestamp,message]' \
		--output table || echo "Error: AWS CLI required or logs not available yet"

# Manually test Lambda function
test-lambda:
	@echo "Manually invoking Lambda function..."
	@aws lambda invoke \
		--function-name "$$(terraform output -raw check_web_name)" \
		--payload '{}' \
		response.json && \
	echo "Response:" && \
	cat response.json && \
	echo "" && \
	rm -f response.json

# Create Lambda deployment package manually
package:
	@echo "Creating Lambda deployment package..."
	@rm -f tmp/check_web.zip
	@zip tmp/check_web.zip src/check_web.py
	@echo "✓ Package created: tmp/check_web.zip"

# Clean Terraform files
clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f tfplan
	rm -f tmp/check_web.zip
	rm -f response.json

# Update secret with new values (requires AWS CLI)
update-secret:
	@echo "Updating secret with values from terraform.tfvars..."
	@terraform apply -target=aws_secretsmanager_secret_version.notification_config_version -auto-approve

# Check if nginx is accessible (for manual testing)
check-nginx:
	@if [ -f terraform.tfvars ]; then \
		URL=$$(grep "^target_url" terraform.tfvars | cut -d'"' -f2); \
		echo "Checking nginx at: $$URL"; \
		curl -s -o /dev/null -w "HTTP Status: %{http_code}\nResponse Time: %{time_total}s\n" "$$URL" || \
		echo "❌ Failed to connect to nginx"; \
	else \
		echo "❌ terraform.tfvars not found"; \
	fi

# Monitor Lambda function metrics
metrics:
	@echo "Getting Lambda function metrics..."
	@aws cloudwatch get-metric-statistics \
		--namespace AWS/Lambda \
		--metric-name Invocations \
		--dimensions Name=FunctionName,Value="$$(terraform output -raw check_web_name)" \
		--statistics Sum \
		--start-time $$(date -d '1 hour ago' --iso-8601) \
		--end-time $$(date --iso-8601) \
		--period 300 \
		--query 'Datapoints[*].[Timestamp,Sum]' \
		--output table || echo "Error: AWS CLI required or no metrics available yet"