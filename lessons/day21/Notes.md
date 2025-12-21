# AWS Policy and Governance using Terraform

**Policy** - Enforcing some rules that an organization should follow  
Examples:

- If a user has not enabled MFA, they cannot delete any resource
- Objects uploaded to S3 must be encrypted at rest/transit (HTTPS)
- Every resource created must have required tags

The action will be restricted if the developer fails to comply. Policy blocks requests that are not approved.

**Governance** - Storing all activities to track compliance

## AWS Configs

- Helps create config rules
- Similar to IAM policies but applied after actions have been performed
- Example: Allows resource creation without tags, but later logs it as non-compliant

## The Project

Creating 6 different config rules that monitor and check for compliance.  
Creating an S3 bucket to store audit logs with encryption, versioning, and blocked public access.

This project implements Audit and Compliance using Policies and Governance, preventing actions via IAM policies, detecting violations, and storing logs in S3.

## Steps:

### 1. Create an S3 Bucket

First, generate a 6-character random string for the suffix:

```hcl
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
```

Create the S3 bucket resource:

```hcl
resource "aws_s3_bucket" "config_bucket" {
  bucket        = "${var.project_name}-config-bucket-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-config-bucket"
    Environment = "governance"
    Purpose     = "aws-config-storage"
    ManagedBy   = "terraform"
  }
}
```

Enable versioning on the Config bucket:

```hcl
resource "aws_s3_bucket_versioning" "config_bucket_versioning" {
  bucket = aws_s3_bucket.config_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

Enable SSE (Server-Side Encryption) for the bucket using AES256:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "config_bucket_encryption" {
  bucket = aws_s3_bucket.config_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

Block public access to the bucket:

```hcl
resource "aws_s3_bucket_public_access_block" "config_bucket_public_access" {
  bucket = aws_s3_bucket.config_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Add policies to the bucket:

```hcl
resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config_bucket.arn
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config_bucket.arn
      },
      {
        Sid    = "AWSConfigBucketPutObject"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.config_bucket.arn,
          "${aws_s3_bucket.config_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.config_bucket_public_access]
}
```

### 2. IAM Policies

Creating IAM policies that restrict actions on AWS resources.

#### 1. Create a custom IAM policy that enforces MFA for deleting S3 objects

```hcl
resource "aws_iam_policy" "mfa_delete_policy" {
  name        = "${var.project_name}-mfa-delete-policy"
  description = "Policy that requires MFA to delete S3 objects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyDeleteWithoutMFA"
        Effect   = "Deny"
        Action   = "s3:DeleteObject"
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}
```

#### 2. Enforce encryption in transit for S3 buckets

```hcl
resource "aws_iam_policy" "encryption_in_transit_policy" {
  name        = "${var.project_name}-encryption-in-transit-policy"
  description = "Policy that requires HTTPS for S3 object uploads"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Action = "s3:PutObject"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

#### 3. Require tagging for resource creation

```hcl
resource "aws_iam_policy" "require_tagging_policy" {
  name        = "${var.project_name}-require-tagging-policy"
  description = "Policy that requires specific tags for EC2 instance creation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RequireEnvironmentTag"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotLike = {
            "aws:RequestTag/Environment" = ["dev", "staging", "prod"]
          }
        }
      }
    ]
  })
}
```

#### 4. Create IAM Role for AWS Config service

Reference video: https://www.youtube.com/watch?v=YPMn0Azq7v0

The `assume_role_policy` allows AWS Config (`config.amazonaws.com`) to assume the role and perform tasks like reading configurations or interacting with other AWS resources.

```hcl
resource "aws_iam_role" "config_role" {
  name = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3_policy" {
  name = "${var.project_name}-config-s3-policy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          aws_s3_bucket.config_bucket.arn,
          "${aws_s3_bucket.config_bucket.arn}/*"
        ]
      }
    ]
  })
}
```

### 3. Config Setup

Set up AWS Config to record compliance and log to the S3 bucket.

Create a Config recorder:

```hcl
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}
```

Create a delivery channel (S3 bucket):

```hcl
resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
  depends_on     = [aws_config_configuration_recorder.main]
}
```

Start the Config recorder:

```hcl
resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}
```

Configure Config rules for compliance checks. These won't prevent resource creation but will log violations in the S3 bucket.

Using a predefined AWS rule:

```hcl
resource "aws_config_config_rule" "s3_public_write_prohibited" {
  name = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}
```

Custom rules can also be created.  
Reference documentation: https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_use-managed-rules.html

### 4. Apply Changes

Run the following Terraform commands to apply changes:

```bash
terraform init
terraform plan
terraform apply --auto-approve
```
