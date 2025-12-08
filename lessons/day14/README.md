# Day 14: Static Website Hosting with CloudFront, Route 53 & HTTPS (Mini Project 1)

## 🎯 Project Overview

This mini project demonstrates how to deploy a production-ready static website on AWS using Terraform. We'll create a complete static website hosting solution with S3 for storage, CloudFront for global content delivery, ACM for HTTPS certificates, and Route 53 for custom domain DNS.

## 🏗️ Architecture

```
Internet → Route 53 (DNS) → CloudFront Distribution (HTTPS) → S3 Bucket (Static Website)
                                      ↑
                              ACM Certificate
```

### Components:

- **S3 Bucket**: Hosts static website files (HTML, CSS, JS) - Private with OAC
- **CloudFront Distribution**: Global CDN for fast content delivery with HTTPS
- **Origin Access Control (OAC)**: Secure access from CloudFront to S3
- **ACM Certificate**: SSL/TLS certificate for HTTPS (optional, with custom domain)
- **Route 53**: DNS management for custom domain (optional)

## 📁 Project Structure

```
day14/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── provider.tf                # AWS provider configuration
├── local.tf                   # Local values
├── terraform.tfvars.example   # Example configuration file
├── README.md                  # This file
└── www/                       # Website source files
    ├── index.html             # Main HTML page
    ├── style.css              # Stylesheet
    └── script.js              # JavaScript functionality
```

## 🚀 Features

### Website Features:

- **Modern Responsive Design**: Works on desktop and mobile
- **Dark/Light Theme Toggle**: Switch between themes (saves preference)
- **Interactive Elements**: Click counter, status updates
- **AWS Branding**: Professional layout showcasing AWS services
- **Animations**: Smooth transitions and loading effects

### Infrastructure Features:

- **S3 Private Bucket**: Secure file storage with OAC
- **CloudFront CDN**: Global content delivery with HTTPS
- **Proper MIME Types**: Fixed content-type headers for all files (prevents download issues)
- **ACM Certificate**: Free SSL/TLS certificate for custom domains
- **Route 53 Integration**: Custom domain support with automatic DNS configuration
- **Automatic Certificate Validation**: DNS validation for ACM certificates
- **Compression**: Gzip compression enabled for faster loading

## 🛠️ Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** installed (version 1.0+)
3. **AWS Account** with sufficient permissions for:
   - S3 bucket creation and management
   - CloudFront distribution creation
   - ACM certificate creation (us-east-1 region)
   - Route 53 hosted zone management (if using custom domain)
4. **(Optional) Custom Domain**: A domain registered in Route 53 or transferred to Route 53

## 📋 Deployment Steps

### Option 1: Deploy with CloudFront Default Domain (No Custom Domain)

This is the simplest option and doesn't require a custom domain.

#### 1. Initialize Terraform

```bash
cd lessons/day14
terraform init
```

#### 2. Review the Plan

```bash
terraform plan
```

#### 3. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm deployment.

#### 4. Access Your Website

After deployment completes, Terraform will output the CloudFront URL:

```
website_url = "https://d123xyz.cloudfront.net"
```

### Option 2: Deploy with Custom Domain (Route 53 + ACM)

If you have a custom domain in Route 53, follow these steps:

#### 1. Get Your Route 53 Hosted Zone ID

```bash
aws route53 list-hosted-zones
```

Copy the `Id` value for your domain (e.g., `/hostedzone/Z1234567890ABC`)

#### 2. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
bucket_name = "your-unique-bucket-name"
create_route53_record = true
domain_name = "yourdomain.com"
route53_zone_id = "Z1234567890ABC"  # Your hosted zone ID
```

#### 3. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

#### 4. Wait for Certificate Validation

ACM certificate validation via DNS typically takes 5-30 minutes. Terraform will wait for validation to complete.

#### 5. Access Your Website

After deployment:

```
website_url = "https://yourdomain.com"
```

Both `yourdomain.com` and `www.yourdomain.com` will work!

## 📊 Resources Created

### Without Custom Domain:

| Resource Type           | Purpose           | Count |
| ----------------------- | ----------------- | ----- |
| S3 Bucket               | Website hosting   | 1     |
| S3 Public Access Block  | Security          | 1     |
| S3 Bucket Policy        | CloudFront access | 1     |
| S3 Objects              | Website files     | 3     |
| CloudFront OAC          | Secure S3 access  | 1     |
| CloudFront Distribution | Global CDN        | 1     |

### With Custom Domain (Additional):

| Resource Type                 | Purpose                | Count |
| ----------------------------- | ---------------------- | ----- |
| ACM Certificate               | HTTPS/SSL              | 1     |
| Route 53 Records (Validation) | Certificate validation | 2     |
| Route 53 A Record             | Domain → CloudFront    | 1     |
| Route 53 A Record (www)       | www subdomain          | 1     |

## 🔧 Configuration Details

### S3 Configuration:

- **Bucket naming**: Configurable via `bucket_name` variable
- **Access**: Private bucket with OAC (Origin Access Control)
- **Content types**: **FIXED** - Proper MIME types prevent file downloads
- **Files uploaded**: All files from `www/` directory

### CloudFront Configuration:

- **Origin**: S3 bucket with OAC authentication
- **Caching**: Standard web caching (1 hour default TTL)
- **HTTPS**: Automatic redirect from HTTP to HTTPS
- **Compression**: Gzip enabled for text files
- **Global**: Available worldwide (PriceClass_100)
- **Certificate**: ACM certificate for custom domain (if configured)

### ACM Certificate (Optional):

- **Region**: us-east-1 (required for CloudFront)
- **Validation**: DNS validation via Route 53
- **Coverage**: Main domain + www subdomain
- **Cost**: Free!

### Route 53 (Optional):

- **A Records**: Alias records pointing to CloudFront
- **Domains**: Both apex domain and www subdomain
- **TTL**: Standard DNS TTL values

## 🐛 Troubleshooting

### Issue: Files are downloading instead of displaying in browser

**Solution**: This has been fixed! The issue was with incorrect `content_type` mapping in S3 objects. The code now properly detects file extensions and sets correct MIME types.

If you deployed before this fix:

```bash
terraform apply  # Re-apply to update S3 object content types
```

### Issue: Certificate validation taking too long

**Cause**: DNS propagation can take time.

**Solution**:

1. Check Route 53 for validation records
2. Wait up to 30 minutes for DNS propagation
3. Verify nameservers are correctly configured

### Issue: Domain not resolving

**Cause**: DNS propagation or incorrect hosted zone.

**Solution**:

1. Verify `route53_zone_id` is correct
2. Check that domain nameservers point to Route 53
3. Wait for DNS propagation (up to 48 hours for domain changes)

### Issue: CloudFront distribution not updating

**Cause**: CloudFront caching.

**Solution**:

```bash
# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id <your-distribution-id> \
  --paths "/*"
```

## 🧹 Cleanup

To destroy all resources and avoid charges:

```bash
terraform destroy
```

Type `yes` when prompted to confirm destruction.

**Note**: CloudFront distributions can take 15-20 minutes to fully delete.

## 📚 Learning Objectives

After completing this project, you should understand:

- ✅ How to configure S3 for static website hosting with OAC
- ✅ Setting up CloudFront distributions with custom domains
- ✅ Managing S3 bucket policies for CloudFront access
- ✅ Creating and validating ACM certificates
- ✅ Configuring Route 53 DNS records
- ✅ Terraform file provisioning with `for_each`
- ✅ Proper MIME type configuration for web assets
- ✅ AWS CDN concepts and caching strategies
- ✅ HTTPS/SSL certificate management
- ✅ DNS management with Route 53

## 🔒 Security Best Practices

This project implements:

- ✅ Private S3 bucket (no public access)
- ✅ Origin Access Control (OAC) for S3
- ✅ HTTPS enforcement (HTTP redirects to HTTPS)
- ✅ TLS 1.2+ for encryption
- ✅ Principle of least privilege for bucket policies

## 💰 Cost Estimation

Approximate monthly costs (US East region):

- **S3**: ~$0.023/GB storage + $0.09/GB transfer
- **CloudFront**: First 1TB free tier, then ~$0.085/GB
- **Route 53**: $0.50/hosted zone + $0.40/million queries
- **ACM**: Free!

For a small static website: **~$1-5/month**

## 🔗 Useful Links

- [AWS S3 Static Website Hosting Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [ACM Certificate Documentation](https://docs.aws.amazon.com/acm/)
- [Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🎉 Next Steps

Consider extending this project with:

- ✅ ~~Custom domain name with Route 53~~ (Implemented!)
- ✅ ~~SSL certificate with AWS Certificate Manager~~ (Implemented!)
- CI/CD pipeline for automatic deployments (GitHub Actions, CodePipeline)
- Multiple environments (dev, staging, prod)
- Advanced CloudFront configurations:
  - Custom error pages (404, 500)
  - Security headers (CSP, HSTS)
  - Lambda@Edge for dynamic content
  - WAF for security
- CloudWatch monitoring and alarms
- S3 versioning for rollback capability

---

**Production Ready**: This configuration is now suitable for production use with custom domains and HTTPS!
