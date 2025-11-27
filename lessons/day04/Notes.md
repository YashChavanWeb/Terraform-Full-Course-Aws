## How Terraform Updates Infrastructure

When you run `terraform apply`:

* Terraform compares the desired state (from your configuration) to the actual state (from the infrastructure).
* If you delete a resource and then run `terraform apply` again, Terraform will compare the state and delete the resource.
* Terraform uses API calls to interact with cloud providers. To manage this, it stores the state of the resources in a file called `terraform.tfstate`.

### Important Notes:

* The `tfstate` file contains sensitive data (e.g., secrets and resource IDs).
* Securing this file is of utmost importance.

---

## Remote Backend

* The `tfstate` file should be stored in a remote location, such as an S3 bucket.
* When you run Terraform commands, it will check the state file in the S3 bucket, compare it with the actual infrastructure, and make the necessary changes.

### Best Practices

1. **Do not delete or modify the state file manually.**

2. **State Locking**:

   * Once a process is using the `tfstate` file, it should not be used by any other process.
   * Multiple users should not execute `terraform plan` or `terraform apply` on the same infrastructure at the same time.
   * The lock will be released only after the process completes.

   **Note**: Initially, DynamoDB was used for managing locking, but now S3 has an inbuilt locking feature.

3. **Isolation of state files**: Store different state files for different environments (e.g., dev, staging, prod).

4. **Regular Backups**: Perform regular backups of the state file.

---

## Implementation

To implement remote backend with S3, follow these steps:

1. **Write the backend configuration** inside the `terraform` block:

   ```hcl
   # backend configuration
   backend "s3" {
     bucket         = "awsbucket.yashchavan"
     key            = "dev/terraform.tfstate"
     region         = "us-east-1"
     encrypt        = true
     use_lockfile   = true
   }
   ```

2. **Create the S3 bucket** manually or through a script/CI/CD pipeline. This bucket will store the actual state file.

3. **Full Example Configuration**:

   ```hcl
   # Configure the AWS Provider
   terraform {

     # Backend configuration
     backend "s3" {
       bucket         = "awsbucket.yashchavan"
       key            = "dev/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       use_lockfile   = true
     }

     required_providers {
       aws = {
         source = "hashicorp/aws"
         version = "~> 6.0"
       }
     }
   }

   provider "aws" {
     region = "ca-central-1"
   }

   # Simple test resource to verify remote backend
   resource "aws_s3_bucket" "test_backend" {
     bucket = "test-remote-backend-${random_string.bucket_suffix.result}"

     tags = {
       Name        = "Test Backend Bucket"
       Environment = "dev"
     }
   }

   resource "random_string" "bucket_suffix" {
     length  = 8
     special = false
     upper   = false
   }
   ```

4. **Terraform Commands**:

   Run the following commands to initialize and apply the configuration:

   ```bash
   terraform init
   ```

   ```bash
   terraform plan
   ```

   ```bash
   terraform apply
   ```

   After running these commands, the state file is stored in the S3 bucket, while a local state file will contain minimal data (e.g., the S3 bucket name). The actual state file in S3 will store all the resource information and secrets.

---

## Practice Commands

Here are some useful Terraform state management commands:

1. **List the resources in the state file**:

   ```bash
   terraform state list
   ```

2. **Show the details of a specific resource in the state file**:

   ```bash
   terraform state show aws_s3_bucket.test_backend
   ```

3. **Remove a resource from the state file (without destroying it)**:

   ```bash
   terraform state rm aws_s3_bucket.test_backend
   ```

4. **Move a resource from one state file to another**:

   ```bash
   terraform state mv aws_s3_bucket.test_backend aws_s3_bucket.test_backend_new
   ```

5. **Pull the state file from the S3 bucket**:

   ```bash
   terraform state pull
   ```

