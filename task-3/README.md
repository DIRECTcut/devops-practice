# Task 3: Lambda-based Nginx Monitoring

This project creates a Lambda function that monitors nginx availability and sends notifications to Slack/Telegram.

## Architecture

Lambda Function → EventBridge (5min trigger) → HTTP Check → Slack/Telegram notification

## Components

1. **Lambda Function**: Python-based HTTP health checker
2. **EventBridge Rule**: Triggers Lambda every 5 minutes  
3. **IAM Role**: Permissions for Lambda execution
4. **Secrets Manager**: Store Slack/Telegram tokens securely
5. **Terraform**: Infrastructure as Code

## Setup Instructions

1. Copy terraform.tfvars.example to terraform.tfvars
2. Configure your notification tokens
3. Deploy with `make apply`