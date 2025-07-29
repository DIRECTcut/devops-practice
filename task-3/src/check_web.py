import json
import urllib3
import boto3
import os
from datetime import datetime
from typing import Dict, Any, Optional

# Initialize HTTP client (urllib3 is included in Lambda runtime)
http = urllib3.PoolManager()

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager')

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda function to monitor nginx availability and send notifications.
    
    This function:
    1. Checks if nginx is responding on the target URL
    2. If not available, sends notification to Slack/Telegram
    3. Returns status information
    """
    
    print(f"Starting nginx health check at {datetime.utcnow().isoformat()}")
    
    try:
        # Get configuration from environment variables
        target_url = os.environ.get('TARGET_URL')
        notification_type = os.environ.get('NOTIFICATION_TYPE', 'slack')  # 'slack' or 'telegram'
        secret_name = os.environ.get('SECRET_NAME')
        
        if not target_url:
            raise ValueError("TARGET_URL environment variable is required")
        
        if not secret_name:
            raise ValueError("SECRET_NAME environment variable is required")
        
        print(f"Checking URL: {target_url}")
        print(f"Notification type: {notification_type}")
        
        # Perform health check
        is_healthy = check_nginx_health(target_url)
        
        if is_healthy:
            print("✅ Nginx is healthy")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'status': 'healthy',
                    'url': target_url,
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        else:
            print("❌ Nginx is unhealthy - sending notification")
            
            # Get notification credentials from Secrets Manager
            notification_config = get_secret(secret_name)
            
            # Send notification
            notification_sent = send_notification(
                notification_type, 
                notification_config, 
                target_url
            )
            
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'status': 'unhealthy',
                    'url': target_url,
                    'notification_sent': notification_sent,
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
            
    except Exception as e:
        print(f"Error in handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def check_nginx_health(url: str, timeout: int = 10) -> bool:
    """
    Check if nginx is responding with HTTP 200.
    
    Args:
        url: The URL to check
        timeout: Request timeout in seconds
        
    Returns:
        True if nginx is healthy, False otherwise
    """
    try:
        print(f"Making HTTP request to {url} with timeout {timeout}s")
        
        response = http.request(
            'GET', 
            url,
            timeout=timeout,
            retries=urllib3.Retry(total=2, backoff_factor=1)
        )
        
        print(f"Response status: {response.status}")
        
        # Consider 200-299 as healthy
        if 200 <= response.status < 300:
            # Also check if response contains expected nginx content
            body = response.data.decode('utf-8', errors='ignore')
            if 'nginx' in body.lower() or 'welcome' in body.lower():
                print("✅ Response contains expected nginx content")
                return True
            else:
                print("⚠️ Response status OK but no nginx content detected")
                return True  # Still consider it healthy if status is OK
        else:
            print(f"❌ Unhealthy status code: {response.status}")
            return False
            
    except Exception as e:
        print(f"❌ Health check failed: {str(e)}")
        return False

def get_secret(secret_name: str) -> Dict[str, str]:
    """
    Retrieve secret from AWS Secrets Manager.
    
    Args:
        secret_name: Name of the secret in Secrets Manager
        
    Returns:
        Dictionary containing secret values
    """
    try:
        print(f"Retrieving secret: {secret_name}")
        
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_string = response['SecretString']
        
        # Parse JSON secret
        return json.loads(secret_string)
        
    except Exception as e:
        print(f"Error retrieving secret: {str(e)}")
        raise

def send_notification(notification_type: str, config: Dict[str, str], target_url: str) -> bool:
    """
    Send notification via Slack or Telegram.
    
    Args:
        notification_type: 'slack' or 'telegram'
        config: Configuration dictionary with tokens/webhooks
        target_url: The URL that failed the health check
        
    Returns:
        True if notification was sent successfully
    """
    try:
        if notification_type.lower() == 'slack':
            return send_slack_notification(config, target_url)
        elif notification_type.lower() == 'telegram':
            return send_telegram_notification(config, target_url)
        else:
            print(f"Unknown notification type: {notification_type}")
            return False
            
    except Exception as e:
        print(f"Error sending notification: {str(e)}")
        return False

def send_slack_notification(config: Dict[str, str], target_url: str) -> bool:
    """Send notification to Slack using webhook."""
    webhook_url = config.get('slack_webhook_url')
    if not webhook_url:
        print("❌ Slack webhook URL not found in configuration")
        return False
    
    message = {
        "text": f"🚨 Nginx Health Check Alert",
        "attachments": [
            {
                "color": "danger",
                "fields": [
                    {
                        "title": "Status",
                        "value": "❌ Nginx is not responding",
                        "short": True
                    },
                    {
                        "title": "Target URL",
                        "value": target_url,
                        "short": True
                    },
                    {
                        "title": "Time",
                        "value": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
                        "short": True
                    }
                ]
            }
        ]
    }
    
    try:
        response = http.request(
            'POST',
            webhook_url,
            body=json.dumps(message),
            headers={'Content-Type': 'application/json'}
        )
        
        if response.status == 200:
            print("✅ Slack notification sent successfully")
            return True
        else:
            print(f"❌ Slack notification failed: {response.status}")
            return False
            
    except Exception as e:
        print(f"❌ Error sending Slack notification: {str(e)}")
        return False

def send_telegram_notification(config: Dict[str, str], target_url: str) -> bool:
    """Send notification to Telegram using bot API."""
    bot_token = config.get('telegram_bot_token')
    chat_id = config.get('telegram_chat_id')
    
    if not bot_token or not chat_id:
        print("❌ Telegram bot token or chat ID not found in configuration")
        return False
    
    message = f"""🚨 *Nginx Health Check Alert*

❌ *Status:* Nginx is not responding
🌐 *URL:* `{target_url}`
🕒 *Time:* {datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")}

Please check your nginx server immediately."""
    
    telegram_url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    
    payload = {
        'chat_id': chat_id,
        'text': message,
        'parse_mode': 'Markdown'
    }
    
    try:
        response = http.request(
            'POST',
            telegram_url,
            fields=payload
        )
        
        if response.status == 200:
            print("✅ Telegram notification sent successfully")
            return True
        else:
            print(f"❌ Telegram notification failed: {response.status}")
            print(f"Response: {response.data.decode('utf-8', errors='ignore')}")
            return False
            
    except Exception as e:
        print(f"❌ Error sending Telegram notification: {str(e)}")
        return False