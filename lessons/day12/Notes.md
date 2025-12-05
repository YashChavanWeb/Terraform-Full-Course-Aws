Here’s the revised version of the Terraform functions, with proper formatting, explanations, and improvements where necessary. I've broken the explanation into sections for clarity.

---

## 1. **Validation Functions**

Terraform allows you to define validation functions within variable declarations. These validations help ensure that the input values meet specific requirements, such as length, regex matching, or value restrictions.

### Example 1: **Validation on Instance Type**

In this example, we're performing two types of validations for the `instance_type` variable:

- **Length Validation:** Ensures the instance type name is between 2 and 20 characters.
- **Regex Validation:** Ensures the instance type matches the pattern for `t2` or `t3` instance types.

```hcl
variable "instance_type" {
  default = "t2.micro"

  # Validation 1 - Length
  validation {
    condition     = length(var.instance_type) >= 2 && length(var.instance_type) <= 20
    error_message = "Instance type must be between 2 and 20 characters long."
  }

  # Validation 2 - Allowed values only t2 and t3 instances
  validation {
    condition     = can(regex("^t[2-3]\\.", var.instance_type))
    error_message = "Instance type must be t2 or t3."
  }
}
```

### Example 2: **Validation with Endswith**

This example uses the `endswith` function to validate that the `backup_name` ends with `_backup`.

```hcl
variable "backup_name" {
  default = "daily_backup"

  validation {
    condition     = endswith(var.backup_name, "_backup")
    error_message = "Backup name must end with '_backup'."
  }
}
```

### Example 3: **Sensitive Variable**

You can mark variables as sensitive, so their values are not exposed in the Terraform output.

```hcl
variable "credentials" {
  default   = "xyz123"
  sensitive = true
}

output "credentials" {
  value     = var.credentials
  sensitive = true
}
```

- **Note:** While marking a variable or output as `sensitive` hides it from logs and output, the value is encoded in base64 in the `terraform.tfstate` file. It's not encrypted, so someone with access to the `tfstate` file can still decode the sensitive data.

---

## 2. **Numeric Functions**

You can use numeric functions like `abs`, `max`, and `min` to process numeric data, even if the values are negative.

### Example: **Convert Negative Values to Positive**

In this example, we process the `monthly_cost` array, convert all values to positive using `abs()`, and find the maximum and minimum costs.

```hcl
variable "monthly_cost" {
  default = [-50, 300, 12, -10, 21]
}

locals {
  # Convert all monthly costs to positive values
  positive_cost = [for cost in var.monthly_cost : abs(cost)]

  # Find the maximum and minimum values
  max_cost = max(local.positive_cost...)
  min_cost = min(local.positive_cost...)
}
```

- **Explanation:** The `abs()` function converts negative values to positive. The spread operator (`...`) is used to unpack the list of values so that `max()` and `min()` functions can operate correctly on them.

---

## 3. **File Handling Functions**

Terraform provides functions like `fileexists()` and `jsondecode()` for file handling. These allow you to read files and parse them as needed.

### Example: **Reading a JSON File**

Here’s how you can check if a JSON file exists, and if so, read and decode its contents.

```hcl
locals {
  # Check if the config.json file exists
  config_file_exists = fileexists("./config.json")

  # If the file exists, decode its contents
  config_data = local.config_file_exists ? jsondecode(file("./config.json")) : null
}
```

- **Explanation:**

  - The `fileexists()` function checks whether the file exists.
  - The `file()` function reads the file content.
  - The `jsondecode()` function converts the JSON string into a map that you can use within your Terraform configuration.
  - If the file doesn’t exist, the `config_data` will be set to `null`.

---

### Example JSON (`config.json`)

Here’s a sample `config.json` file that contains database and API configuration:

```json
{
  "database": {
    "host": "localhost",
    "port": 5432,
    "user": "admin",
    "password": "admin123"
  },
  "api": {
    "endpoint": "https://api.example.com",
    "timeout": 30
  }
}
```

---

### Summary

- **Validation Functions** allow you to ensure that input variables meet specific conditions, such as length, regex, and allowed values.
- **Sensitive Variables** help you keep sensitive data hidden in logs and output, although they are encoded in base64 in the `tfstate` file.
- **Numeric Functions** like `abs()`, `max()`, and `min()` can help manipulate numeric values, including converting negative values to positive.
- **File Handling Functions** allow you to check for file existence and read JSON files, which can be useful for integrating external configurations into your Terraform setup.
