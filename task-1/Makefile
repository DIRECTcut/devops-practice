# EC2 Nginx Setup Makefile
.PHONY: help init validate plan apply destroy clean ssh output fmt check test test-docker

# Default target
help:
	@echo "Available targets:"
	@echo "  make init      - Initialize Terraform"
	@echo "  make validate  - Validate Terraform configuration"
	@echo "  make plan      - Show deployment plan"
	@echo "  make apply     - Deploy infrastructure"
	@echo "  make destroy   - Destroy infrastructure"
	@echo "  make ssh       - SSH to the instance"
	@echo "  make output    - Show outputs"
	@echo "  make fmt       - Format Terraform files"
	@echo "  make check     - Run validation and formatting check"
	@echo "  make clean     - Clean Terraform files"
	@echo "  make test      - Test user-data script locally with Docker"

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
	terraform apply "tfplan"

# Destroy infrastructure
destroy:
	terraform destroy

# Show outputs
output:
	@terraform output -json | jq -r '.ssh_command.value'
	@echo ""
	@terraform output -json | jq -r '.website_url.value'

# SSH to the instance
ssh:
	@echo "Connecting to EC2 instance..."
	@$(shell terraform output -json | jq -r '.ssh_command.value')

# Clean Terraform files
clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f plan.out

# Show instance status
status:
	@echo "Instance ID: $$(terraform output -raw instance_id)"
	@echo "Public IP: $$(terraform output -raw public_ip)"
	@echo "Website: $$(terraform output -raw website_url)"

# Run a targeted plan for specific resource
plan-target:
	@read -p "Enter resource to target (e.g., aws_instance.nginx_server): " target; \
	terraform plan -target=$$target

# Import existing resources
import:
	@echo "Example: make import RESOURCE=aws_instance.nginx_server ID=i-1234567890abcdef0"
	@[ -z "$(RESOURCE)" ] && echo "Error: RESOURCE not set" && exit 1 || true
	@[ -z "$(ID)" ] && echo "Error: ID not set" && exit 1 || true
	terraform import $(RESOURCE) $(ID)