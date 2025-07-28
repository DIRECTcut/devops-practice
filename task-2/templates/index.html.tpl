<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${site_title}</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            border-radius: 10px;
            padding: 2rem;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            max-width: 600px;
            text-align: center;
        }
        h1 {
            color: #333;
            margin-bottom: 1rem;
        }
        .info {
            background: #f8f9fa;
            border-radius: 5px;
            padding: 1rem;
            margin: 1rem 0;
            border-left: 4px solid #667eea;
        }
        .timestamp {
            color: #666;
            font-size: 0.9rem;
            margin-top: 1rem;
        }
        .badge {
            display: inline-block;
            background: #28a745;
            color: white;
            padding: 0.2rem 0.8rem;
            border-radius: 15px;
            font-size: 0.8rem;
            margin: 0.2rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 ${site_title}</h1>
        
        <div class="info">
            <h3>✅ Successfully Deployed version 3!</h3>
            <p>This static website is hosted on Amazon S3 and delivered globally via CloudFront CDN.</p>
        </div>

        <div class="info">
            <h4>🚀 Infrastructure Details:</h4>
            <div class="badge">S3 Bucket</div>
            <div class="badge">Versioning Enabled</div>
            <div class="badge">CloudFront CDN</div>
            <div class="badge">Terraform Managed</div>
        </div>

        <div class="info">
            <p><strong>S3 Bucket:</strong> <code>${bucket_name}</code></p>
            <p><strong>Deployed via:</strong> Terraform Infrastructure as Code</p>
            <p><strong>CDN:</strong> Amazon CloudFront for global delivery</p>
        </div>

        <div class="timestamp">
            🕒 Last updated: ${timestamp}
        </div>
    </div>
</body>
</html>