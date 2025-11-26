### Creating an S3 Bucket Using Terraform

1. **Resource Configuration for S3 Bucket**

   First, write a Terraform configuration for the S3 bucket resource:

   ```hcl
   resource "aws_s3_bucket" "demo_first_bucket" {
     bucket = "terraform-yashchavan-123"

     tags = {
       Name        = "First bucket"
       Environment = "Dev"
     }
   }
   ```

2. **Configure AWS CLI**

   Before executing Terraform, configure your AWS credentials:

   ```bash
   aws configure
   ```

3. **Execute Terraform Plan**

   Run the `terraform plan` command to see the changes Terraform will apply:

   ```bash
   terraform plan
   ```

4. **Apply Terraform Changes**

   Apply the configuration to create the resources. You can also use the `--auto-approve` flag to skip the confirmation prompt:

   ```bash
   terraform apply --auto-approve
   ```

   After applying, the S3 bucket will be created, and you can verify its existence in the AWS console.

5. **Make Changes and Reapply**

   You can modify the Terraform configuration file as needed. Once changes are made, run `terraform plan` and `terraform apply` again to apply the updates.

6. **Destroy Resources**

   If you want to remove the resources created by Terraform, run the `terraform destroy` command. You can also use `--auto-approve` to skip confirmation:

   ```bash
   terraform destroy --auto-approve
   ```

