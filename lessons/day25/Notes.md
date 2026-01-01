# Terraform Resource Migration

## Need and Use Case

- When we have resources created manually in AWS (e.g., part of legacy applications)
- Moving forward, we want to manage them using Terraform
- To do this, we must migrate these resources into Terraform so they are managed by IaC going forward
- If we simply write Terraform code and run `terraform apply`, it will try to create new resources and fail because they already exist
- To avoid this, we first need to **import** these existing resources into Terraform’s state

### How Terraform State Works

- Terraform uses a **tfstate file** – the brain of Terraform
- When we run `terraform apply`, Terraform:
  1. Checks the tfstate file to understand the current infrastructure
  2. Compares your desired infrastructure (code) with the actual infrastructure (state)
  3. Makes changes only where differences exist
- The tfstate file stores the actual infrastructure details
- If resources weren’t created by Terraform, they won’t be in the tfstate file
- Therefore, to ensure tfstate reflects all existing resources, we must import them

## Important Interview Question

**Question:**  
You accidentally deleted your Terraform state file and lost the infrastructure state. How would you manage the resources using Terraform again?

**Answer:**

1. First, import all existing resources back into Terraform state using `terraform import`
2. Alternatively, restore the tfstate file from a backup if available

## Migration Methods

1. **`terraform import`** (Native Terraform) – Recommended method
2. **Terraformer** – Open-source CLI tool
3. **AWS2TF** – Open-source CLI tool

## Demo

### Step 1: Create a Resource Manually in AWS

- For testing, create an EC2 instance manually in AWS
- Create a security group along with it (name it appropriately)
- Take note of the security group ID and instance ID

### Step 2: Write Terraform Code for the Same Resource

Create Terraform configuration for:

- EC2 instance (using AMI data source)
- VPC (using data source)
- Security group with ingress rules for SSH (22), HTTP (80), and HTTPS (443)
- Variables as needed

### Step 3: Test Without Import

Run:

```bash
terraform plan
```

(When prompted for VPC ID, hit Enter to use default in that region)

Then:

```bash
terraform apply
```

**Error:** Duplicate resource – Terraform tries to create new resources that already exist.

### Step 4: Import Resources

Import the security group first:

```bash
terraform import aws_security_group.app_sg sg-0c398cb65a93047f2
```

(The resource ID is taken from AWS Console)

**Import successful.**

### Step 5: Verify Import

List all resources managed by Terraform:

```bash
terraform state list
```

Show details of the imported security group:

```bash
terraform state show aws_security_group.app_sg
```

### Important Note

- The description (and other attributes) of the imported resource must match what’s defined in your Terraform configuration
- If they differ, Terraform will plan to replace the resource
- To avoid replacement, either:
  1. Copy the exact description from AWS Console into your Terraform code
  2. Use `lifecycle` block to ignore changes:

```hcl
resource "aws_security_group" "app_sg" {
  # ... configuration ...

  lifecycle {
    ignore_changes = [description]
  }
}
```

### Step 6: Apply Configuration

After importing, run:

```bash
terraform plan
```

```bash
terraform apply
```

Now Terraform will manage the imported security group without errors.

Repeat the same import process for the EC2 instance using its instance ID.
