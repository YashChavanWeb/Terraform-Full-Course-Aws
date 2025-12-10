# IAM Policies for Groups
# Attach appropriate AWS managed policies to each group based on their role

# ============================================
# Education Group Policies
# ============================================

# Read-only access to AWS services for Education team
resource "aws_iam_group_policy_attachment" "education_readonly" {
  group      = aws_iam_group.education.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Allow Education group to access S3 for learning materials
resource "aws_iam_group_policy_attachment" "education_s3" {
  group      = aws_iam_group.education.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ============================================
# Managers Group Policies
# ============================================

# Managers get billing access to view costs
resource "aws_iam_group_policy_attachment" "managers_billing" {
  group      = aws_iam_group.managers.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

# Managers get IAM read access to view users and roles
resource "aws_iam_group_policy_attachment" "managers_iam_readonly" {
  group      = aws_iam_group.managers.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

# Managers get CloudWatch read access for monitoring
resource "aws_iam_group_policy_attachment" "managers_cloudwatch" {
  group      = aws_iam_group.managers.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# ============================================
# Engineers Group Policies
# ============================================

# Engineers get PowerUser access (full access except IAM and Organizations)
resource "aws_iam_group_policy_attachment" "engineers_poweruser" {
  group      = aws_iam_group.engineers.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Engineers get EC2 full access for infrastructure work
resource "aws_iam_group_policy_attachment" "engineers_ec2" {
  group      = aws_iam_group.engineers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Engineers get S3 full access for storage management
resource "aws_iam_group_policy_attachment" "engineers_s3" {
  group      = aws_iam_group.engineers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# ============================================
# Custom Policy - All Users Must Use MFA
# ============================================

# Custom policy that denies access if MFA is not enabled
resource "aws_iam_policy" "require_mfa" {
  name        = "RequireMFAPolicy"
  path        = "/policies/"
  description = "Policy that denies most actions if MFA is not enabled"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowViewAccountInfo"
        Effect = "Allow"
        Action = [
          "iam:GetAccountPasswordPolicy",
          "iam:ListVirtualMFADevices"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnVirtualMFADevice"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice"
        ]
        Resource = "arn:aws:iam::*:mfa/$${aws:username}"
      },
      {
        Sid    = "AllowManageOwnUserMFA"
        Effect = "Allow"
        Action = [
          "iam:DeactivateMFADevice",
          "iam:EnableMFADevice",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice"
        ]
        Resource = "arn:aws:iam::*:user/$${aws:username}"
      },
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken",
          "iam:ChangePassword"
        ]
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

# Attach MFA policy to all groups
resource "aws_iam_group_policy_attachment" "education_mfa" {
  group      = aws_iam_group.education.name
  policy_arn = aws_iam_policy.require_mfa.arn
}

resource "aws_iam_group_policy_attachment" "managers_mfa" {
  group      = aws_iam_group.managers.name
  policy_arn = aws_iam_policy.require_mfa.arn
}

resource "aws_iam_group_policy_attachment" "engineers_mfa" {
  group      = aws_iam_group.engineers.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
