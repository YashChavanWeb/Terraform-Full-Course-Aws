## Blue-Green Deployment with AWS Elastic Beanstalk

### Project Tasks

- **Infrastructure Setup**: Create an Elastic Beanstalk Application and necessary IAM roles.
- **Artifact Management**: Use S3 for storing application version bundles.
- **Blue Environment**: Deploy the initial production version (v1.0) to the "Blue" environment.
- **Green Environment**: Deploy the new version (v2.0) to the "Green" staging environment.
- **Traffic Swap**: Perform a zero-downtime deployment by swapping CNAMEs between Blue and Green.
- **Future Enhancements**:
  - Automate the package creation and versioning in a CI/CD pipeline.
  - Implement canary deployments for gradual traffic shifting.
- **Production Roadmap**:
  - Integrate Route53 for weighted routing.
  - Add RDS databases with externalized connection strings to survive environment termination.

---

### Implementation Steps

#### 1. **Core Infrastructure & IAM Roles**

Set up the Elastic Beanstalk Application, S3 bucket for artifacts, and necessary IAM roles for EC2 instances and the EB service itself.

**File:** `main.tf`

```hcl
resource "aws_elastic_beanstalk_application" "app" {
  name        = var.app_name
  description = "Blue-Green Deployment Demo Application"
}

# S3 Bucket for storing application versions
resource "aws_s3_bucket" "app_versions" {
  bucket = "${var.app_name}-versions-${data.aws_caller_identity.current.account_id}"
}

# IAM Role for EC2 Instances (Instance Profile)
resource "aws_iam_instance_profile" "eb_ec2_profile" {
  name = "${var.app_name}-eb-ec2-profile"
  role = aws_iam_role.eb_ec2_role.name
}
```

> **Roles & Profiles**:
>
> - `eb_ec2_profile`: Attached to EC2 instances to allow them to talk to S3, CloudWatch, etc.
> - `eb_service_role`: Used by the Elastic Beanstalk service to provision resources (ELB, ASG, etc.) on your behalf.

---

#### 2. **Package Application Versions**

Before deploying, we zip the application source code. We modify the version text in the HTML/Node.js app to distinguish between v1 (Blue) and v2 (Green).

**Script:** `package-apps.ps1` (or `.sh`)

```powershell
# Creates v1.zip (Blue) and v2.zip (Green)
Compress-Archive -Path "app-v1/*" -DestinationPath "app-v1.zip" -Force
Compress-Archive -Path "app-v2/*" -DestinationPath "app-v2.zip" -Force
```

> **Artifacts**: These zip files are the deployment units. In a real scenario, these would be built by Jenkins/GitHub Actions.

---

#### 3. **Define Blue Environment (Production - v1)**

Upload the v1 artifact to S3, register it as an Application Version, and launch the Blue Environment.

**File:** `blue-environment.tf`

```hcl
# 1. Upload Artifact to S3
resource "aws_s3_object" "v1" {
  bucket = aws_s3_bucket.app_versions.id
  key    = "app-v1.zip"
  source = "app-v1.zip"
}

# 2. Register Application Version
resource "aws_elastic_beanstalk_application_version" "v1" {
  name        = "v1.0.0"
  application = aws_elastic_beanstalk_application.app.name
  bucket      = aws_s3_bucket.app_versions.id
  key         = aws_s3_object.v1.key
}

# 3. Create Blue Environment
resource "aws_elastic_beanstalk_environment" "blue" {
  name                = "${var.app_name}-blue"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.1.1 running Node.js 20"
  version_label       = aws_elastic_beanstalk_application_version.v1.name

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_ec2_profile.name
  }
}
```

> **Solution Stack**: Defines the platform (OS + Runtime), e.g., Amazon Linux 2 running Node.js.

---

#### 4. **Define Green Environment (Staging - v2)**

Repeat the process for the v2 artifact. This environment runs locally but is unconnected to the main production URL initially.

**File:** `green-environment.tf`

```hcl
resource "aws_elastic_beanstalk_environment" "green" {
  name                = "${var.app_name}-green"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.1.1 running Node.js 20"
  version_label       = aws_elastic_beanstalk_application_version.v2.name

  # ... same settings as Blue
}
```

---

#### 5. **Apply and Verify**

Deploy the infrastructure. Both environments will spin up simultaneously.

```bash
terraform apply --auto-approve
```

**Outputs:**

```bash
blue_environment_url = "my-app-blue.us-east-1.elasticbeanstalk.com"
green_environment_url = "my-app-green.us-east-1.elasticbeanstalk.com"
```

> **Testing**: Visit the Blue URL to see "Version 1". Visit the Green URL to see "Version 2".

---

#### 6. **The Swap (Blue/Green Deployment)**

This is the core concept. We swap the CNAMEs (DNS records) of the two environments.

- **Before**: `production.com` -> Blue (v1), `staging.com` -> Green (v2)
- **After**: `production.com` -> Green (v2), `staging.com` -> Blue (v1)

**Script:** `swap-environments.ps1`

```powershell
aws elasticbeanstalk swap-environment-cnames `
    --source-environment-name "my-app-blue" `
    --destination-environment-name "my-app-green" `
    --region "us-east-1"
```

> **Zero Downtime**: AWS updates the DNS weighting behind the scenes. Users are seamlessly shifted to the new environment.  
> **Rollback**: If artifacts are found in v2, simply verify `swap-environment-cnames` again to revert traffic to Blue immediately.

---

### Troubleshooting & Common Issues

| Issue                    | Cause                     | Solution                                                           |
| :----------------------- | :------------------------ | :----------------------------------------------------------------- |
| **Environment goes Red** | Health check failing.     | Check `var/log/web.stdout.log` or `eb-engine.log` via the console. |
| **Swap command fails**   | Environments not "Ready". | Ensure both environments are Green/Ready before swapping.          |
| **502 Bad Gateway**      | Nginx/App not running.    | Verify the `package.json` start script matches existing files.     |
| **Credentials Error**    | AWS CLI not configured.   | Run `aws configure` before running the swap script.                |

---

### **Key Concepts: Blue/Green vs. Canary vs. Rolling**

1.  **Blue/Green (This Demo)**:

    - **Pros**: Instant cutover, easy rollback, no version mixing.
    - **Cons**: Requires double the resources (cost) during deployment.

2.  **Rolling Deployment**:

    - **Pros**: Cheaper (updates instances in batches).
    - **Cons**: Deployment takes longer; mix of v1/v2 users during update; harder rollback.

3.  **Canary**:
    - **Pros**: Risk mitigation (expose only 10% of users to new version).
    - **Cons**: Complex routing setup (often requires Route53 or ALB weighting).
