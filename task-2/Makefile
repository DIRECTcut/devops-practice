# S3 Static Website with CloudFront Makefile
.PHONY: help init validate plan apply destroy clean output website

# Default target
help:
	@echo "Available targets:"
	@echo "  make init      - Initialize Terraform"
	@echo "  make validate  - Validate Terraform configuration"
	@echo "  make plan      - Show deployment plan"
	@echo "  make apply     - Deploy infrastructure"
	@echo "  make destroy   - Destroy infrastructure"
	@echo "  make output    - Show outputs"
	@echo "  make website   - Open website in browser"
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
	@echo "=== CloudFront Website URL ==="
	@terraform output -raw website_url
	@echo ""
	@echo "=== S3 Bucket ==="
	@terraform output -raw s3_bucket_name
	@echo ""
	@echo "=== CloudFront Distribution ID ==="
	@terraform output -raw cloudfront_distribution_id

# Open website in browser (requires xdg-open on Linux)
website:
	@echo "Opening website in browser..."
	@xdg-open "$$(terraform output -raw website_url)" 2>/dev/null || \
	echo "Please open: $$(terraform output -raw website_url)"

# Clean Terraform files
clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f plan.out

# Show CloudFront cache invalidation command
invalidate:
	@aws cloudfront create-invalidation --distribution-id $$(terraform output -raw cloudfront_distribution_id) --paths '/*'