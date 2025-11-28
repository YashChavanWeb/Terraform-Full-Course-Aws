## Why Do We Need Variables?

- **Reuse Values:** We use variables to utilize certain values multiple times.
- **Simplify Code:** Instead of typing the same values repeatedly, we can reference the variables.

---

## Variables in Terraform

### 1. Based on Purpose

- **Input Variables:** We provide values to these variables.
- **Output Variables:** These allow us to retrieve values from resources after they are created.
- **Local Variables:** These are used to store values for use within a specific module or configuration. You can define multiple local variables within the same block.

### 2. Based on Value (Type Constraints)

---

## Defining an Input Variable

To define an input variable in Terraform, you can use the following syntax:

```hcl
variable "environment" {
    default = "dev"
    type    = string
}
```

Now, you can use this variable in your resources by referencing it with `var`:

```hcl
tags = {
    Name        = "my-vpc"
    Environment = var.environment
}
```

---

## Defining a Local Variable

If you want to use a variable in a string, you can do so using `${}` syntax.

### Example:

```hcl
resource "aws_instance" "ec2" {
    ami             = "ami-0c55b159cbfafe1f0"
    instance_type   = "t2.micro"
    tags = {
        Name        = "${var.environment}-ec2"   # Using the variable
        Environment = var.environment
    }
}
```

### Defining Multiple Local Variables

You can define multiple local variables within a single `locals` block:

```hcl
locals {
    bucket_name = "${var.environment}.yashchavan-bucket"
    vpc_name    = "${var.environment}.yashchavan-vpc"
}
```

Now, you can use these variables in your resources like this:

```hcl
resource "aws_s3_bucket" "s3" {
    bucket = local.bucket_name
    tags = {
        Name        = local.bucket_name
        Environment = var.environment
    }
}
```

Similarly, you can use the local variables for the VPC.

---

## Running Terraform

To test everything, use the following commands:

```bash
terraform plan
```

```bash
terraform apply
```

---

## Output Variables

- After a resource is created, you can store certain resource information in an output variable.
- During `terraform plan`, these variables will be empty, but after `terraform apply`, the values will be assigned.

### Example:

```hcl
output "vpc_id" {
    value = aws_vpc.sample.id
}

output "ec2_id" {
    value = aws_instance.example.id
}
```

You can use these output values in other resources.

To view the values of output variables:

```bash
terraform output
```

---

## Precedence of Variable Definitions

Terraform uses the following precedence order when resolving variables:

1. **Default Values:** The values you define in the variable block.

   ```hcl
   variable "environment" {
       default = "dev"
       type    = string
   }
   ```

2. **Environment Variables:** You can define environment variables in the terminal.

   ```bash
   export TF_VAR_environment="dev"
   ```

3. **TF Vars File:** You can specify values in a `.tfvars` file.

   ```hcl
   environment = "pre-prod"
   ```

4. **JSON Format:** You can use a `.tfvars.json` file.

   ```json
   {
     "environment": "dev"
   }
   ```

5. **Command-Line Option:** The highest precedence comes from the `-var` or `-var-file` options provided in the `terraform` commands.

   Example:

   ```bash
   terraform plan -var="environment=dev"
   ```

In this case, the environment will be set to `dev`, overriding any previously defined values.
