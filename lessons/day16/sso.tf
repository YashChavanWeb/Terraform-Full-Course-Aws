# AWS SSO (Identity Center) Configuration
# For better user management in production environments

# ============================================
# Prerequisites
# ============================================
# Before using AWS SSO, you need to:
# 1. Enable AWS Organizations (if not already enabled)
# 2. Enable AWS IAM Identity Center in the AWS Console

# ============================================
# Data Sources for SSO
# ============================================

# Get the SSO instance (must be enabled in the console first)
data "aws_ssoadmin_instances" "this" {}

# ============================================
# SSO Permission Sets
# ============================================

# Permission Set for Administrators
resource "aws_ssoadmin_permission_set" "admin" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  name             = "AdministratorAccess"
  description      = "Full administrator access to AWS resources"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H" # 8 hour sessions

  tags = {
    "ManagedBy" = "Terraform"
    "Purpose"   = "Admin Access"
  }
}

# Permission Set for Developers/Engineers
resource "aws_ssoadmin_permission_set" "developer" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  name             = "DeveloperAccess"
  description      = "Developer access with PowerUser permissions"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT4H" # 4 hour sessions

  tags = {
    "ManagedBy" = "Terraform"
    "Purpose"   = "Developer Access"
  }
}

# Permission Set for Read-Only Access
resource "aws_ssoadmin_permission_set" "readonly" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  name             = "ReadOnlyAccess"
  description      = "Read-only access to view AWS resources"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT2H" # 2 hour sessions

  tags = {
    "ManagedBy" = "Terraform"
    "Purpose"   = "Read Only Access"
  }
}

# Permission Set for Billing Access
resource "aws_ssoadmin_permission_set" "billing" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  name             = "BillingAccess"
  description      = "Access to view billing and cost information"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT2H" # 2 hour sessions

  tags = {
    "ManagedBy" = "Terraform"
    "Purpose"   = "Billing Access"
  }
}

# ============================================
# Attach AWS Managed Policies to Permission Sets
# ============================================

# Admin Permission Set - Attach AdministratorAccess
resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin[0].arn
}

# Developer Permission Set - Attach PowerUserAccess
resource "aws_ssoadmin_managed_policy_attachment" "developer" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  permission_set_arn = aws_ssoadmin_permission_set.developer[0].arn
}

# ReadOnly Permission Set - Attach ReadOnlyAccess
resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.readonly[0].arn
}

# Billing Permission Set - Attach AWSBillingReadOnlyAccess
resource "aws_ssoadmin_managed_policy_attachment" "billing" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.billing[0].arn
}

# ============================================
# SSO Groups (Identity Store)
# ============================================

# Note: These groups are created in the SSO Identity Store
# They are separate from IAM groups and used for SSO access

resource "aws_identitystore_group" "admins" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  display_name      = "SSO-Admins"
  description       = "SSO Group for Administrators"
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

resource "aws_identitystore_group" "developers" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  display_name      = "SSO-Developers"
  description       = "SSO Group for Developers and Engineers"
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

resource "aws_identitystore_group" "viewers" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  display_name      = "SSO-Viewers"
  description       = "SSO Group for Read-Only Access"
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# ============================================
# Output SSO Information
# ============================================

output "sso_instance_arn" {
  description = "ARN of the SSO instance"
  value       = length(data.aws_ssoadmin_instances.this.arns) > 0 ? tolist(data.aws_ssoadmin_instances.this.arns)[0] : "SSO not enabled"
}

output "sso_start_url" {
  description = "SSO Start URL for users to access"
  value       = "https://<your-sso-start-url>.awsapps.com/start"
}

output "sso_permission_sets" {
  description = "List of permission sets created"
  value = length(data.aws_ssoadmin_instances.this.arns) > 0 ? {
    admin     = aws_ssoadmin_permission_set.admin[0].name
    developer = aws_ssoadmin_permission_set.developer[0].name
    readonly  = aws_ssoadmin_permission_set.readonly[0].name
    billing   = aws_ssoadmin_permission_set.billing[0].name
  } : {}
}
