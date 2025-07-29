# Validation script for Task 3 configuration

# Validate that required variables are provided
resource "null_resource" "validate_target_url" {
  count = var.target_url == "" ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Error: target_url variable is required. Please set it in terraform.tfvars' && exit 1"
  }
}

# Validate notification configuration based on type
resource "null_resource" "validate_slack_config" {
  count = var.notification_type == "slack" && var.slack_webhook_url == "" ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Error: slack_webhook_url is required when notification_type is slack' && exit 1"
  }
}

resource "null_resource" "validate_telegram_config" {
  count = var.notification_type == "telegram" && (var.telegram_bot_token == "" || var.telegram_chat_id == "") ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Error: telegram_bot_token and telegram_chat_id are required when notification_type is telegram' && exit 1"
  }
}

# Output validation status
output "validation_status" {
  description = "Configuration validation status"
  sensitive = true
  value = {
    target_url_set        = var.target_url != ""
    notification_type     = var.notification_type
    slack_config_valid    = var.notification_type != "slack" || var.slack_webhook_url != ""
    telegram_config_valid = var.notification_type != "telegram" || (var.telegram_bot_token != "" && var.telegram_chat_id != "")
  }
}