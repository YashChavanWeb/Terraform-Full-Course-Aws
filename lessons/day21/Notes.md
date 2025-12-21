# AWS Policy and Governance using Terraform

Policy - Enforcing some rules that a organization should follow
Eg: if a user has not enabled MFA then he cannot delete any resource in terraform
Eg: if you upload an object in s3 bucket then it should be encrypted in rest / transit (HTTPS)
Eg: every resource created should have the tags mentioned
The action will be restricted if the developer fails to do so
Policy blocks the request that is not approved

Governance - storing all the activities - to know what is compliant

## AWS CONFIGS

- helps us create config rules
- similar to IAM policies
- but will be applied after the action has been performed
  Eg: it will allow you to create resource with no tags, but later it will log that as a non-compliant resource

## The Project

Creating 6 different config rules
These rules will monitor and check for compliance
We will be creating a S3 bucket - store the audit logs
this bucket will be encrypted, versioned and public access will be blocked on this bucket

This project is for Audit and Compliance using Policies and Governance
in which we will be preventing some actions using IAM policies, detecting as well, and store in S3 bucket

## Steps:

### 1. Create a S3 bucket

first we need a 6 chars random string generated for the suffix

```
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
```

now we can create the S3 bucket resource

```
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

after creating the bucket, we have to enable versioning for it

```
# Enable versioning on Config bucket
resource "aws_s3_bucket_versioning" "config_bucket_versioning" {
  bucket = aws_s3_bucket.config_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

now we can enable the sse for the bucket
we have multiple options for the rule, the most prominent is - using AES256
or if we are using the s3 keys then we can also use the kms
currently we are using AES256

```
# Enable encryption on Config bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "config_bucket_encryption" {
  bucket = aws_s3_bucket.config_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

and then also we will block the bucket public access

```
# Block public access to Config bucket
resource "aws_s3_bucket_public_access_block" "config_bucket_public_access" {
  bucket = aws_s3_bucket.config_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Then we have to add different policies onto the bucket

```
# S3 Bucket Policy for Config
resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allows AWS Config to get the ACL (Access Control List) of the bucket.
        # This is required for AWS Config to verify that the bucket is configured correctly.

        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config_bucket.arn
      },
      {
       # Allows AWS Config to list the contents of the bucket.
       # Ensures that AWS Config can verify the bucket’s existence.

        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config_bucket.arn
      },
      {
        # Allows AWS Config to put objects into the bucket.
        # Requires that objects uploaded by AWS Config must have the "bucket-owner-full-control" ACL.

        Sid    = "AWSConfigBucketPutObject"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config_bucket.arn}/*"
        Condition = {
          StringEquals = {

            # Ensures that objects uploaded by AWS Config must have the "bucket-owner-full-control" ACL.
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        # Denies all actions on the bucket if the request is not made over a secure (HTTPS) connection.

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

  depends_on = [aws_s3_bucket_public_access_block.config_bucket_public_access] # To ensure that the bucket is created before the policy is applied
}
```

That is it for the configuration of the S3 Bucket

### 2. IAM Policies

In the IAM we are creating multiple policies, that are restricting the actions on the AWS resources

#### 1. Create a custom IAM policy that enforces MFA for deleting S3 objects

```
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

          # everything is same, just here we have to put this condition rest all can be understood
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}
```

second is enforcing encryption in transit for s3 bucket
so in the policy we have to just change a few things:

```
        ...
        Effect   = "Deny"
        Action   = "s3:PutObject"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
```

third is require tagging for resource creation

```
    # only on creating ec2 instances we are applying this policy
        Action = [
          "ec2:RunInstances"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
            # if the request tag is not like any of these then request will be blocked
          StringNotLike = {
            "aws:RequestTag/Environment" = ["dev", "staging", "prod"]
          }
        }
```

and more

#### 4. Create IAM Role for AWS Config service

Refer this video for reference: https://www.youtube.com/watch?v=YPMn0Azq7v0

The assume_role_policy allows AWS Config (config.amazonaws.com) to "take on" the role and perform tasks like reading configurations or interacting with other AWS resources.

```
# IAM Role for AWS Config Service
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

# Attach managed policy to Config Role
resource "aws_iam_role_policy_attachment" "config_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Additional policy for Config to write to S3
resource "aws_iam_role_policy" "config_s3_policy" {
  name = "${var.project_name}-config-s3-policy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # write the logs to the S3 Bucket
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

now we need to setup the config in order to record the compliance and then log it into the S3 bucket
steps:
create a config recorder

```
# AWS Config Recorder
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}
```

then a delivery channel - Eg: s3 bucket

```
# AWS Config Delivery Channel
resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
  depends_on     = [aws_config_configuration_recorder.main]
}
```

then start the config recorder

```
# Start the Config Recorder
resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}
```

and then finally we need to configure the config rules for compliance check
it will not stop the resource from creation, but will log it in the s3 bucket if any issue is found (eg: a rule is not followed)

using a predefined rule by aws

```
# Config Rule: Ensure S3 buckets do not allow public write
resource "aws_config_config_rule" "s3_public_write_prohibited" {
  name = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}
```

like this we can also create custom rules as well
refer this documentation for more reference - https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_use-managed-rules.html

now we can run the 3 terraform command to apply the changes

```
terraform init
terraform plan --auto-approve
terraform apply --auto-approve
```
