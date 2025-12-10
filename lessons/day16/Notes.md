## User Management in Terraform

### Project Tasks

- Create IAM users from a CSV file
- Create multiple IAM groups
- Assign IAM users to groups dynamically using conditionals and loops
- Provide console access with temporary passwords (enforced reset on first login)
- **Future Enhancements:**
  - Attach IAM policies to groups
  - Enable MFA
- **Production Roadmap:**
  - Implement AWS SSO for centralized user management
  - Extend CSV schema with additional attributes (email, phone number, etc.)

---

### Implementation Steps

#### 1. **Read User Data from CSV**

Create a local variable to decode and store CSV data as a list of maps for iteration.

**File:** `local.tf`

```hcl
locals {
  users = csvdecode(file("users.csv"))
}
```

**Verification Output:**

```hcl
output "user_names" {
  value = [for user in local.users : "${user.first_name} ${user.last_name}"]
}
```

> **Function:** `csvdecode()` reads CSV-formatted data and converts it into a list of maps (e.g., `[{first_name: "John", last_name: "Doe", department: "Engineering"}, ...]`).

---

#### 2. **Fetch AWS Account Information**

Retrieve the current AWS account ID using the AWS provider data source.

**File:** `data.tf`

```hcl
data "aws_caller_identity" "current" {}
```

**Verification Output:**

```hcl
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
```

> **Prerequisite:** Ensure AWS CLI is configured (`aws configure`) for the target account.

---

#### 3. **Create IAM Users**

Use `for_each` to iterate over the user list and create individual IAM users.

**File:** `users.tf`

```hcl
resource "aws_iam_user" "users" {
  for_each = { for user in local.users : user.first_name => user }

  name = lower("${substr(each.value.first_name, 0, 1)}${each.value.last_name}")
  path = "/users/"

  tags = {
    "DisplayName" = "${each.value.first_name} ${each.value.last_name}"
    "Department"  = each.value.department
    "JobTitle"    = each.value.job_title
  }
}
```

> **Naming Convention:** Creates a username from the first initial and last name (e.g., `jdoe`).  
> **Tagging:** Adds metadata for filtering and organization.

---

#### 4. **Create Console Login Profiles**

Generate login profiles with temporary passwords, enforcing a password reset on first login.

**File:** `login-profiles.tf`

```hcl
resource "aws_iam_user_login_profile" "users" {
  for_each = aws_iam_user.users

  user                    = each.value.name
  password_reset_required = true

  lifecycle {
    ignore_changes = [
      password_length,
      password_reset_required,
    ]
  }
}
```

> **Security:** `password_reset_required = true` forces users to change their password upon initial login.  
> **Lifecycle Block:** Prevents Terraform from attempting to revert changes to these attributes if modified outside Terraform (e.g., in the AWS Console).

**Securely Output Password Status:**

```hcl
output "user_passwords" {
  value = {
    for user, profile in aws_iam_user_login_profile.users :
    user => "Password created - user must reset on first login"
  }
  sensitive = true
}
```

> **Note:** AWS does not output the plaintext password by default unless PGP encryption is configured. Passwords should be managed via a secrets manager in production.

---

#### 5. **Create IAM Groups**

Define groups to organize users by role or department.

**File:** `groups.tf`

```hcl
resource "aws_iam_group" "education" {
  name = "Education"
  path = "/groups/"
}

resource "aws_iam_group" "managers" {
  name = "Managers"
  path = "/groups/"
}

resource "aws_iam_group" "engineers" {
  name = "Engineers"
  path = "/groups/"
}
```

---

#### 6. **Dynamic User-to-Group Assignment**

Use conditional logic within `for` loops to filter users based on tags and assign them to groups.

**File:** `group-membership.tf`

_Example 1: Department-based Assignment_

```hcl
resource "aws_iam_group_membership" "education_members" {
  name  = "education-group-membership"
  group = aws_iam_group.education.name

  users = [
    for user in aws_iam_user.users : user.name if user.tags.Department == "Education"
  ]
}
```

_Example 2: Job Title-based Assignment (using regex)_

```hcl
resource "aws_iam_group_membership" "managers_members" {
  name  = "managers-group-membership"
  group = aws_iam_group.managers.name

  users = [
    for user in aws_iam_user.users : user.name if contains(keys(user.tags), "JobTitle") && can(regex("Manager|CEO", user.tags.JobTitle))
  ]
}
```

> **Logic:** `can(regex(...))` safely attempts pattern matching; `contains(keys(...), "JobTitle")` ensures the tag exists before checking its value.

---

#### 7. **Apply and Verify**

Run a plan to preview resources and then apply.

```bash
terraform plan | grep -i "will be created"
terraform apply --auto-approve
```

---

### **Password Management Notes**

- Terraform does **not** store or output the generated password in plain text by default.
- To retrieve initial passwords (if not using PGP), you must use the AWS Console: **IAM → Users → select user → Security credentials tab → Manage console access**.
- For production, integrate with AWS Secrets Manager or use PGP key encryption with the `pgp_key` argument in `aws_iam_user_login_profile`.

---

### **Terraform State Troubleshooting Commands**

| Command                                                | Purpose                                                        |
| ------------------------------------------------------ | -------------------------------------------------------------- |
| `terraform show`                                       | Inspect the current state file.                                |
| `terraform state list`                                 | List all resources in the state.                               |
| `terraform state show 'aws_iam_user.users["Michael"]'` | Show attributes of a specific resource.                        |
| `terraform refresh`                                    | Synchronize the state file with the real-world infrastructure. |

---

## **Additional Security & Management Features**

### 1. **Attach IAM Policies to Groups**

Assign AWS-managed or custom policies to groups to control permissions.

**File:** `policies.tf`

_Attach Managed Policies:_

```hcl
resource "aws_iam_group_policy_attachment" "education_readonly" {
  group      = aws_iam_group.education.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_group_policy_attachment" "managers_billing" {
  group      = aws_iam_group.managers.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}
```

_Create and Attach a Custom MFA Enforcement Policy:_

```hcl
resource "aws_iam_policy" "require_mfa" {
  name        = "RequireMFAPolicy"
  path        = "/policies/"
  description = "Policy that denies most actions if MFA is not enabled"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# Attach the custom MFA policy to a group
resource "aws_iam_group_policy_attachment" "engineers_require_mfa" {
  group      = aws_iam_group.engineers.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
```

> **Policy Logic:** Denies all actions except a safe list of MFA setup/management actions if the user's session is not authenticated with MFA.

---

### 2. **Enable Multi-Factor Authentication (MFA)**

Create virtual MFA devices and enforce a strong password policy.

**File:** `mfa.tf`

_Create Virtual MFA Devices:_

```hcl
resource "aws_iam_virtual_mfa_device" "users" {
  for_each = aws_iam_user.users

  virtual_mfa_device_name = each.value.name
  path                    = "/mfa/"

  tags = {
    "User"      = each.value.name
    "ManagedBy" = "Terraform"
  }
}
```

> **Note:** Terraform creates the virtual MFA device resource. The user must complete activation by scanning the QR code with an authenticator app (e.g., Google Authenticator). This step cannot be automated via Terraform.

_Enforce Account Password Policy:_

```hcl
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90    # Passwords expire after 90 days
  password_reuse_prevention      = 5     # Prevent reuse of the last 5 passwords
}
```

---

### 3. **Setup AWS SSO (IAM Identity Center) for Production**

AWS SSO provides centralized, scalable user management across multiple AWS accounts and applications.

**File:** `sso.tf`

_Prerequisites (must be completed in AWS Console first):_

1. Enable AWS Organizations.
2. Enable AWS IAM Identity Center.

_Conditional SSO Resource Creation:_

```hcl
data "aws_ssoadmin_instances" "this" {}

resource "aws_ssoadmin_permission_set" "admin" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  name             = "AdministratorAccess"
  description      = "Full administrator access to AWS resources"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H" # 8-hour session duration
}

resource "aws_identitystore_group" "developers" {
  count = length(data.aws_ssoadmin_instances.this.arns) > 0 ? 1 : 0

  display_name      = "SSO-Developers"
  description       = "SSO Group for Developers and Engineers"
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}
```

> **Conditional Logic (`count`):** Resources are only created if SSO is enabled (`arns` list is not empty), preventing errors in non-SSO environments.

**Benefits of AWS SSO over Standard IAM Users:**

- **Centralized Management:** Single pane for user access across multiple AWS accounts and business applications.
- **Single Sign-On (SSO):** Users have one set of credentials for all integrated services.
- **External Identity Provider Integration:** Connect to Okta, Azure AD, or other SAML 2.0 providers.
- **Enhanced Audit Trail:** Centralized logging for compliance and security reviews.
- **Scalability:** More efficient for managing large numbers of users compared to individual IAM users.
