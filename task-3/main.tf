# Task 3: Lambda-based Nginx Monitoring
# This configuration creates:
# 1. Lambda function for nginx health checking
# 2. EventBridge rule for 5-minute scheduling
# 3. IAM roles and permissions
# 4. Secrets Manager for notification credentials
# 5. CloudWatch Logs for monitoring

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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

variable "target_url" {
  description = "URL to monitor (nginx instance from task 1)"
  type        = string
  # This should be the public IP from task 1
}

variable "notification_type" {
  description = "Notification type: 'slack' or 'telegram'"
  type        = string
  default     = "slack"
  
  validation {
    condition     = contains(["slack", "telegram"], var.notification_type)
    error_message = "Notification type must be either 'slack' or 'telegram'."
  }
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications (if using Slack)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token (if using Telegram)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Telegram chat ID (if using Telegram)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "function_name" {
  description = "Name for the Lambda function"
  type        = string
  default     = "nginx-health-monitor"
}

# Data source to get current AWS account info
data "aws_caller_identity" "current" {}

# Random suffix for secret naming (avoid deletion conflicts)
resource "random_string" "secret_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create ZIP archive for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/check_web.py"
  output_path = "${path.module}/tmp/check_web.zip"
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.function_name}-role"
    Purpose     = "nginx-monitoring"
    Environment = "dev"
  }
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.notification_config.arn
      }
    ]
  })
}

# Secrets Manager secret for notification configuration
resource "aws_secretsmanager_secret" "notification_config" {
  name        = "${var.function_name}-config-${random_string.secret_suffix.result}"
  description = "Configuration for nginx monitoring notifications"

  tags = {
    Name        = "${var.function_name}-config"
    Purpose     = "nginx-monitoring"
    Environment = "dev"
  }
}

# Secret version with notification configuration
resource "aws_secretsmanager_secret_version" "notification_config_version" {
  secret_id = aws_secretsmanager_secret.notification_config.id
  
  secret_string = jsonencode({
    slack_webhook_url    = var.slack_webhook_url
    telegram_bot_token   = var.telegram_bot_token
    telegram_chat_id     = var.telegram_chat_id
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.function_name}-logs"
    Purpose     = "nginx-monitoring"
    Environment = "dev"
  }
}

# Lambda function
resource "aws_lambda_function" "nginx_monitor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "check_web.handler"
  runtime         = "python3.9"
  timeout         = 30
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TARGET_URL        = var.target_url
      NOTIFICATION_TYPE = var.notification_type
      SECRET_NAME       = aws_secretsmanager_secret.notification_config.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name        = var.function_name
    Purpose     = "nginx-monitoring"
    Environment = "dev"
  }
}

# EventBridge (CloudWatch Events) rule for scheduling
resource "aws_cloudwatch_event_rule" "nginx_monitor_schedule" {
  name                = "${var.function_name}-schedule"
  description         = "Trigger nginx monitoring every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name        = "${var.function_name}-schedule"
    Purpose     = "nginx-monitoring"
    Environment = "dev"
  }
}

# EventBridge target to invoke Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.nginx_monitor_schedule.name
  target_id = "NginxMonitorLambdaTarget"
  arn       = aws_lambda_function.nginx_monitor.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nginx_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.nginx_monitor_schedule.arn
}

# Outputs
output "check_web_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.nginx_monitor.function_name
}

output "check_web_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.nginx_monitor.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.notification_config.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for monitoring Lambda execution"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "monitoring_schedule" {
  description = "EventBridge rule schedule"
  value       = aws_cloudwatch_event_rule.nginx_monitor_schedule.schedule_expression
}