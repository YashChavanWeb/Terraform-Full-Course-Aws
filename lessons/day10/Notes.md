# Terraform Expressions

- **Replacement of functions**: Help us avoid rewriting code.
- **Create meaningful insights**: Improve the clarity and readability of the code.

### 1. Conditional Expressions

Syntax:
`condition ? true_value : false_value`

Examples:

- Choose instance type based on the environment.
- Enable/disable monitoring based on configuration.
- Select different AMIs based on the region.
- Set different resource counts for environments.
- Apply environment-specific tags.

Example:

```hcl
resource "aws_instance" "my-instance-1" {
  ami = "ami-0c55b159cbfafe1f0"

  # Choose instance type based on environment
  instance_type = var.environment == "dev" ? "t2.micro" : "t3.micro"

  count = 2
  tags = {
    Name = "my-instance-1"
    Env  = var.environment
  }
}
```

To verify the instance type:

1. Run `terraform init`
2. Then check the instance type with:

   ```bash
   terraform plan | grep "instance_type"
   ```

### 2. Dynamic Blocks

Dynamic blocks help you define nested blocks with multiple values.

Structure:

```hcl
dynamic "name" {
    for_each = list
    content {
        # Nested block content
    }
}
```

Explanation:

- `for_each` iterates over a list or map.
- `content` defines what each block should contain.
- Access values using `block_name.value` or `block_name.key`.

**Example: Creating a security group with multiple ingress rules**

First, create a security group with a single ingress rule:

```hcl
resource "aws_security_group" "my-sg" {
  name        = "my-sg"
  description = "my-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

To add multiple ingress rules, use a dynamic block. First, define a variable with the ingress rules:

```hcl
variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
```

Then, use the dynamic block to iterate over the `ingress_rules` variable:

```hcl
resource "aws_security_group" "my-sg" {
  name        = "my-sg"
  description = "my-sg"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

### 3. Splat Expressions

Splat expressions allow you to retrieve multiple values in a single line.

**Example: Get a list of all instance IDs**

To do this, first create a local variable containing all the instance IDs. Since we're using `count`, the `*` operator will consider all values:

```hcl
locals {
  # Retrieve instance IDs for all instances
  instance_ids = aws_instance.my-instance-1[*].id
}
```

Finally, output all the instance IDs:

```hcl
output "all_instance_ids" {
  value = local.instance_ids
}
```
