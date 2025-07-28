# Task 2: S3 Static Website with CloudFront

This project demonstrates how to create a static website hosted on Amazon S3 with global delivery via CloudFront CDN using Terraform.

## Architecture Overview

```
Internet → CloudFront → S3 Bucket → index.html
          (Global CDN)  (Storage)   (Content)
```

## Key Learning Points

### 1. S3 Static Website Hosting
- **Bucket Configuration**: S3 can host static websites directly
- **Versioning**: Enabled to track file changes and allow rollbacks
- **Security**: Private bucket with CloudFront-only access (no public access)

### 2. CloudFront CDN
- **Global Delivery**: Content cached at edge locations worldwide
- **HTTPS**: Automatic SSL/TLS encryption
- **Caching**: Configurable TTL (Time To Live) for performance
- **Origin Access Control (OAC)**: Secure S3 access without public permissions

### 3. Infrastructure as Code Benefits
- **Reproducible**: Same setup every time
- **Version Controlled**: Track infrastructure changes
- **Automated**: No manual clicking in AWS console
- **Documented**: Code serves as documentation

## File Structure

```
task-2/
├── main.tf                    # Main Terraform configuration
├── templates/
│   └── index.html.tpl        # HTML template with variables
├── terraform.tfvars.example  # Example variables
├── Makefile                  # Automation commands
└── README.md                 # This documentation
```

## Key Terraform Resources

1. **aws_s3_bucket**: Creates the storage bucket
2. **aws_s3_bucket_versioning**: Enables file versioning
3. **aws_s3_object**: Uploads the HTML file
4. **aws_cloudfront_distribution**: Creates the CDN
5. **aws_cloudfront_origin_access_control**: Secure bucket access
6. **aws_s3_bucket_policy**: Allows CloudFront to read files

## Security Features

- **Private S3 Bucket**: No public access, only CloudFront can read
- **HTTPS Only**: CloudFront redirects HTTP to HTTPS
- **IAM Policies**: Least privilege access using bucket policies
- **Origin Access Control**: Modern secure method (replaces Origin Access Identity)

## Deployment Steps

1. **Setup Variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Deploy Infrastructure**:
   ```bash
   make init
   make plan
   make apply
   ```

3. **Get Website URL**:
   ```bash
   make output
   ```

4. **Open Website**:
   ```bash
   make website
   ```

## Important Notes

### CloudFront Deployment Time
- Initial deployment: 15-20 minutes (CloudFront distribution creation)
- Updates: 5-10 minutes (content propagation to edge locations)

### Caching Behavior
- **Default TTL**: 1 hour (3600 seconds)
- **Max TTL**: 24 hours (86400 seconds)
- **Cache Invalidation**: Use `make invalidate` for immediate updates

### Cost Considerations
- **S3**: Very low cost for storage and requests
- **CloudFront**: First 1TB/month is free tier eligible
- **No EC2 costs**: Serverless architecture

## Advanced Features You Could Add

1. **Custom Domain**: Route 53 domain with SSL certificate
2. **CI/CD Pipeline**: Automated deployments on git push
3. **Multiple Environments**: dev/staging/prod configurations
4. **Error Pages**: Custom 404/500 error pages
5. **Compression**: Gzip compression for faster loading
6. **Security Headers**: HSTS, CSP, X-Frame-Options

## Cleanup

```bash
make destroy
```

This will remove all AWS resources and stop any charges.

## Troubleshooting

### Common Issues

1. **Bucket name conflicts**: S3 bucket names are globally unique
   - Solution: Change `bucket_name` in terraform.tfvars

2. **CloudFront not showing updates**: Content is cached
   - Solution: Wait or run cache invalidation

3. **Access denied errors**: Bucket policy or OAC issues
   - Solution: Check CloudFront distribution status (wait for deployment)

### Useful Commands

```bash
# Check CloudFront distribution status
aws cloudfront get-distribution --id $(terraform output -raw cloudfront_distribution_id)

# Invalidate cache manually
aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"

# Check S3 bucket contents
aws s3 ls s3://$(terraform output -raw s3_bucket_name)
```