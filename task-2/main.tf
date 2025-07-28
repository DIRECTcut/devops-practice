# Task 2: S3 Static Website with CloudFront
# This configuration creates:
# 1. S3 bucket for static website hosting
# 2. Simple index.html file
# 3. Versioning enabled
# 4. CloudFront distribution for global delivery
# 5. Outputs the CloudFront URL

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
  # This will be required - no default to force user to specify
}

variable "site_title" {
  description = "Title for the website"
  type        = string
  default     = "My Static Website"
}