# Terraform Functions

Terraform uses **HCL** (HashiCorp Configuration Language), which is a configuration language and not a programming language. As a result, we cannot write custom functions, but we can use the functions provided by Terraform.

---

## Terraform Console

The Terraform Console helps us execute Terraform commands interactively without creating actual files.

To enter the console:

```bash
terraform console
```

---

## String Functions

- **upper()**: Converts a string to uppercase
  Example:

  ```hcl
  upper("hello")  # Output: "HELLO"
  ```

- **lower()**: Converts a string to lowercase
  Example:

  ```hcl
  lower("HELLO")  # Output: "hello"
  ```

- **trim()**: Removes leading and trailing whitespace (or specific characters)
  Example:

  ```hcl
  trim(" hello ", " ")  # Output: "hello"
  trim(" hello ", "h")  # Output: " ello "
  ```

- **replace()**: Replaces a string with another string
  Example:

  ```hcl
  replace("hello world", " ", "-")  # Output: "hello-world"
  ```

- **substr()**: Gets a substring from a string (start index and length)
  Example:

  ```hcl
  substr("hello", 1, 2)  # Output: "el"
  ```

---

## Numeric Functions

- **max()**: Returns the maximum value
  Example:

  ```hcl
  max(1, 2, 3)  # Output: 3
  ```

- **min()**: Returns the minimum value
  Example:

  ```hcl
  min(1, 2, 3)  # Output: 1
  ```

- **abs()**: Returns the absolute value
  Example:

  ```hcl
  abs(-1)  # Output: 1
  ```

---

## Collection Functions

- **length()**: Returns the length of a collection (list, set, etc.)
  Example:

  ```hcl
  length([1, 2, 3])  # Output: 3
  ```

- **concatenate()**: Concatenates two collections
  Example:

  ```hcl
  concatenate([1, 2, 3], [4, 5, 6])  # Output: [1, 2, 3, 4, 5, 6]
  ```

- **merge()**: Merges key-value pairs (maps)
  Example:

  ```hcl
  merge({a = 1, b = 2})  # Output: {"a" = 1, "b" = 2}
  ```

---

## Type Conversion Functions

- **toset()**: Converts a list to a set (removes duplicates)
  Example:

  ```hcl
  toset([1, 2, 2, 3])  # Output: [1, 2, 3]
  ```

- **tonumber()**: Converts a string to a number
  Example:

  ```hcl
  tonumber("1")  # Output: 1
  ```

---

## Date and Time Functions

- **timestamp()**: Returns the current timestamp in ISO 8601 format
  Example:

  ```hcl
  timestamp()  # Output: "2022-01-01T00:00:00Z"
  ```

- **formatdate()**: Formats a date according to a given format
  Example:

  ```hcl
  formatdate("DD-MM-YYYY", timestamp())  # Output: "01-01-2022"
  ```

---

## Execution

After using functions and making changes, we can refresh the Terraform state and then apply the changes.

1. **Refresh** the Terraform state:

   ```bash
   terraform refresh
   ```

2. **Plan** and apply the changes:

   ```bash
   terraform plan
   ```

---

## Examples

### Example 1: Validating Bucket Name

We use a `local` value to format and validate the bucket name by removing spaces and special characters:

```hcl
formatted_bucket_name = replace(
  replace(substr(tolower(var.bucket_name), 0, 63), " ", "-"),
  "!",
  ""
)
```

This creates a valid bucket name by converting to lowercase, trimming spaces, and removing the `!` character.

### Example 2: Port List for Security Groups

First, define a variable with allowed ports:

```hcl
variable "allowed_ports" {
  default = "22,80,443"
}
```

Convert the string to a list using the `split()` function:

```hcl
port_list = split(",", var.allowed_ports)
```

Then iterate over the list for security group rules:

```hcl
sg_rules = [for port in local.port_list : {
  name = "port-${port}"
  port = port
}]
```

### Example 3: Instance Sizes Based on Environment

Define a variable for instance sizes based on the environment:

```hcl
variable "instance_sizes" {
  default = {
    dev     = "t2.micro"
    staging = "t2.small"
    prod    = "t2.medium"
  }
}
```

Then use the `lookup()` function in the locals:

```hcl
instance_size = lookup(var.instance_sizes, var.environment, "t2.micro")
```

Here, if the environment is not found, the default value `"t2.micro"` is used.
