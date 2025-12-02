# Type Constraints in Terraform

## Variables (Based on Value)

### 1. Primitives

- **String**: `fullName = "Yash Chavan"`
- **Number**: `age = 22`
- **Boolean**: `isStudent = true`

#### Example: Number

A simple use case for creating a specified number of instances.

**Note**: After making changes, you can run:

```
terraform plan
```

to see the changes that will be made.

#### `variables.tf`

```hcl
variable "instance_count" {
  type        = number
  description = "Number of EC2 instances to create"
}
```

#### `terraform.tfvars`

```hcl
instance_count = 2
```

#### `main.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0e8459476fed2e23b"
  instance_type = "t2.micro"
  count         = var.instance_count
}
```

---

### 2. String Example

For defining a region:

#### `variables.tf`

```hcl
variable "region" {
  type        = string
  description = "AWS region"
}
```

#### `terraform.tfvars`

```hcl
region = "us-west-2"
```

#### `main.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0e8459476fed2e23b"
  instance_type = "t2.micro"
  count         = var.instance_count    # number
  region        = var.region            # string
}
```

---

### 3. Boolean Example

You can use booleans directly without defining them in `variables.tf` or `terraform.tfvars`.

#### `main.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0e8459476fed2e23b"
  instance_type = "t2.micro"
  count         = var.instance_count    # number
  region        = var.region            # string
  monitoring    = true                  # boolean
}
```

---

## 2. Non-Primitives

### a. List

A list is an ordered collection of values. For example, CIDR blocks for a security group.

#### `variables.tf`

```hcl
variable "cidr_block" {
  description = "List of CIDR blocks for the security group"
  type        = list(string)   # List of strings (datatype cannot change)
  default     = ["0.0.0.0/0", "10.0.0.0/24", "172.16.0.0/16", "192.168.0.0/16"]
}
```

#### `main.tf`

```hcl
resource "aws_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_ipv4         = var.cidr_block[0]  # Accessing elements in the list
}
```

You can also use the entire list:

```hcl
cidr_blocks = var.cidr_block
```

Another example for allowed VM types:

#### `variables.tf`

```hcl
variable "allowed_vm_types" {
  description = "List of allowed VM types"
  type        = list(string)
  default     = ["t2.micro", "t2.small", "t2.medium"]
}
```

---

### b. Set

A set is an unordered collection of unique values. Unlike lists, you cannot access set elements by index, but you can convert a set to a list if needed.

#### `variables.tf`

```hcl
variable "allowed_region" {
  description = "Allowed regions for the instances"
  type        = set(string)
  default     = ["us-west-2", "us-east-1"]
}
```

#### `main.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0e8459476fed2e23b"
  instance_type = "t2.micro"
  count         = var.instance_count    # number
  region        = toList(var.allowed_region)[0]  # Convert set to list
  monitoring    = true                  # boolean
}
```

**Note**: Sets do not allow duplicates, and you cannot access elements by index.

---

### c. Map

A map is a collection of key-value pairs. For example, EC2 instance tags.

#### `variables.tf`

```hcl
variable "tags" {
  description = "Tags to apply to the EC2 instances"
  type        = map(string)
  default     = {
    Name        = "WebServer"
    Environment = "Production"
    Project     = "Terraform"
  }
}
```

#### `main.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0e8459476fed2e23b"
  instance_type = "t2.micro"
  count         = var.instance_count    # number
  region        = toList(var.allowed_region)[0]  # set converted to list
  monitoring    = true                  # boolean
  tags          = var.tags               # map of values
}
```

---

### d. Tuple

A tuple is an ordered collection that can hold different data types. This is useful when you want to group multiple values of different types together.

#### `variables.tf`

```hcl
variable "ingress_values" {
  description = "Ingress values for the security group"
  type        = tuple([number, string, number])   # Order matters
  default     = [443, "tcp", 443]
}
```

#### `main.tf`

```hcl
resource "aws_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  from_port         = var.ingress_values[0]  # Use tuple index
  to_port           = var.ingress_values[2]
  protocol          = var.ingress_values[1]
  cidr_ipv4         = var.cidr_block[0]  # Accessing elements in the list
}
```

---

### e. Object

An object is a collection of key-value pairs with potentially different types for each value. You can use complex data types inside an object.

#### `variables.tf`

```hcl
variable "config" {
  description = "Configuration for the EC2 instances"
  type = object({
    instance_type    = string
    region           = string
    cidr_block       = list(string)
    allowed_vm_types = list(string)
    allowed_region   = set(string)
    tags             = map(string)
    ingress_values   = tuple([number, string, number])
  })
}
```

#### `main.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0e8459476fed2e23b"
  instance_type = "t2.micro"
  count         = var.instance_count    # number
  monitoring    = true                  # boolean
  tags           = var.config.tags

  region = var.config.region  # Accessing object values
}
```

---
