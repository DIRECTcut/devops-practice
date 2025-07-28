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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
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

# Random ID for bucket naming (S3 bucket names must be globally unique)
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for static website
resource "aws_s3_bucket" "website" {
  bucket = "${var.bucket_name}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "Static Website Bucket"
    Environment = "dev"
    Purpose     = "static-website"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "website_versioning" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create HTML content using Terraform's templatefile function
locals {
  index_html_content = templatefile("${path.module}/templates/index.html.tpl", {
    site_title  = var.site_title
    bucket_name = aws_s3_bucket.website.bucket
    timestamp   = timestamp()
  })
}

# Upload index.html to S3
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = local.index_html_content
  content_type = "text/html"

  # Enable ETags for versioning and caching
  etag = md5(local.index_html_content)

  tags = {
    Name = "Website Index"
    Type = "HTML"
  }
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# S3 Bucket Public Access Block (we need to allow public read for CloudFront)
resource "aws_s3_bucket_public_access_block" "website_pab" {
  bucket = aws_s3_bucket.website.id

  # Allow CloudFront to access the bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control (OAC) - Modern replacement for OAI
resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "${aws_s3_bucket.website.bucket}-oac"
  description                       = "OAC for ${aws_s3_bucket.website.bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  # Origin configuration - where CloudFront gets content from
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
    origin_id                = "S3-${aws_s3_bucket.website.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CloudFront distribution for ${aws_s3_bucket.website.bucket}"

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600  # 1 hour
    max_ttl     = 86400 # 24 hours
  }

  # Geographic restriction (optional)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL Certificate (using CloudFront default)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "Static Website CDN"
    Environment = "dev"
  }
}

# S3 Bucket Policy to allow CloudFront access
data "aws_iam_policy_document" "website_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.website.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website_distribution.arn]
    }
  }
}

# Apply the bucket policy
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website_bucket_policy.json

  depends_on = [
    aws_cloudfront_distribution.website_distribution
  ]
}

# Outputs
output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.website_distribution.id
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = aws_cloudfront_distribution.website_distribution.domain_name
}

output "website_url" {
  description = "Website URL via CloudFront"
  value       = "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website.bucket
}

output "s3_website_endpoint" {
  description = "S3 website endpoint (for direct access)"
  value       = aws_s3_bucket_website_configuration.website_config.website_endpoint
  sensitive   = false
}