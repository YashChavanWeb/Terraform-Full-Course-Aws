# Terraform Lifecycle Rules

## Life Cycle Rule

- Controls how a resource is created, updated, and destroyed.
- We need this:

  - To improve security
  - To prevent accidental deletion of resources
  - To control the order of resource creation

For example:

- `ignore_changes`: It will ignore changes for a specific attribute.

## Lifecycle Methods:

- `ignore_changes`: It will ignore changes for a specific attribute.
- `prevent_destroy`: It will prevent the deletion of a resource unless someone updates this lifecycle rule to `false`.
- `create_before_destroy`: It will create the resource before destroying the old one.
- `replace_triggered_by`: (Sets dependencies between multiple resources) It will replace the resource when the attribute value changes.
  **Example**: If we have a security group resource on which an EC2 instance is dependent, we can configure it so that when the security group changes, the EC2 instance will be replaced with a new one.
- `pre` and `post` conditions: Add validations before and after creating the resource.

## Examples:

### 1. Create Before Destroy

Basic example of creating a resource using an AMI.

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0ff8a91507f77f867"
  instance_type = "t2.micro"
  region        = tolist(var.allowed_region)[0]
  tags          = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
```

- After some time, if we change the AMI ID and then apply again:

  - It will create the new instance and destroy the old one.
  - If not enabled, it will destroy the older instance first. If an error occurs while creating the new instance, users will face downtime.
  - This feature is very helpful because the default behavior of Terraform is to destroy the resource first and then create the new one.

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0130c3a072f3832ff"
  instance_type = "t2.micro"
  region        = tolist(var.allowed_region)[0]
  tags          = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
```

### 2. Prevent Destroy

This will prevent the deletion of a resource unless someone updates the lifecycle rule to `false`.

```hcl
lifecycle {
  prevent_destroy = true
}
```

- Multiple lifecycle rules can be added to the same resource.
- Now, if we run:

```bash
terraform destroy
```

It will throw an error and prevent the resource from being deleted unless the rule is changed to `false`.

### 3. Ignore Changes

Tells Terraform to ignore changes to specified resource attributes. Terraform won't attempt to revert these changes.

```hcl
resource "aws_autoscaling_group" "app_servers" {
  # ... other configuration ...

  desired_capacity = 2

  lifecycle {
    ignore_changes = [
      desired_capacity,  # Ignore capacity changes by auto-scaling
      load_balancers     # Ignore if added externally
    ]
  }
}
```

- In this example:

  - If the capacity was updated through the UI (using Auto-scaling group), changing the capacity to 1.
  - If we run `terraform apply` again, the capacity would not change, as Terraform will ignore that change.

### 4. Replace Triggered By

When a security group changes, the EC2 instance gets replaced.

```hcl
resource "aws_security_group" "app_sg" {
  name = "app-security-group"
  # ... security rules ...
}

resource "aws_instance" "app_with_sg" {
  ami                     = data.aws_ami.amazon_linux_2.id
  instance_type           = "t2.micro"
  vpc_security_group_ids  = [aws_security_group.app_sg.id]

  lifecycle {
    replace_triggered_by = [
      aws_security_group.app_sg.id  # Replace instance when SG changes
    ]
  }
}
```

### 5. Pre and Post Conditions

Here, we have a condition and an error message. Both follow the same format, but one checks before resource creation and the other checks after.

```hcl
resource "aws_s3_bucket" "regional_validation" {
  bucket = "validated-region-bucket"

  lifecycle {
    precondition {
      condition     = contains(var.allowed_regions, data.aws_region.current.name)
      error_message = "ERROR: Can only deploy in allowed regions: ${join(", ", var.allowed_regions)}"
    }

    postcondition {
      condition     = contains(keys(var.tags), "Compliance")
      error_message = "ERROR: Compliance tag is required"
    }
  }
}
```
