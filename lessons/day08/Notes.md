## Terraform Meta Arguments

Some arguments are provided by the cloud provider (e.g., AWS), while others are meta-arguments provided by Terraform.

### Example of Provider Arguments:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

### Example of Terraform Meta Arguments:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  count         = 2  # This is a meta-argument provided by Terraform
}
```

## Creating Resources

- When there are multiple files, Terraform typically creates resources in alphabetical order of the file names.
- However, if there is only one file with multiple resources, the order of creation is random unless explicitly defined using `depends_on`.

## Meta Arguments

### 1. `depends_on`

`depends_on` is used to create explicit dependencies between resources. It ensures that one resource will not be provisioned until another resource is created.

For example, if we have two resources, `A` and `B`:

- Terraform will wait for resource `A` to be created before provisioning resource `B`.

### 2. `count`

The `count` argument is used to create multiple instances of a resource. It takes a numerical value, which represents the number of instances to create.

### 3. `for_each`

The `for_each` argument is used to iterate over a list or set of values, creating a resource for each element in the collection.

### 4. `provider`

The `provider` argument is a plugin that helps Terraform connect to a cloud provider like AWS, Azure, etc.

Example:

```hcl
provider "aws" {
  region = "us-east-1"
}
```

### 5. `lifecycle`

The `lifecycle` block allows you to control the behavior of resource creation and deletion. Some common lifecycle arguments include:

- `create_before_destroy`: Ensures that a new resource is created before the old one is destroyed.
- `prevent_destroy`: Prevents Terraform from destroying the resource.
- `ignore_changes`: Ignores changes to certain attributes.
- `replace_triggered_by`: Specifies when a resource should be replaced based on changes to other resources.

## Examples

### Example of `count`

Here’s how you can use `count` to create multiple S3 buckets based on a list:

```hcl
variable "bucket_names" {
  type    = list(string)
  default = ["yashchavanweb.bucket-1", "yashchavanweb.bucket-2", "yashchavanweb.bucket-3"]
}
```

Then, use `count` to create multiple S3 buckets:

```hcl
resource "aws_s3_bucket" "first_bucket" {
  count  = 3  # Number of resources to create
  bucket = var.bucket_names[count.index]  # Iterate over the list using count.index
}
```

### Example of `for_each`

If you want to create resources based on a set of values, you can use `for_each`:

```hcl
variable "bucket_names_set" {
  type    = set(string)
  default = ["yashchavanweb.bucket-1", "yashchavanweb.bucket-2", "yashchavanweb.bucket-3"]
}
```

Then, use `for_each` to create the buckets:

```hcl
resource "aws_s3_bucket" "second_bucket" {
  for_each = var.bucket_names_set  # Iterate over the set

  bucket = each.value  # Access the value directly
}
```

Note: In a set, you can use either `each.key` or `each.value`. The main difference arises when using a `map`, which contains key-value pairs.

### Example of `depends_on`

To set explicit dependencies between resources, use `depends_on`. For example, let's create two S3 buckets, where the second bucket depends on the first one:

```hcl
resource "aws_s3_bucket" "first_bucket" {
  count  = 2  # Number of resources to create
  bucket = var.bucket_names[count.index]  # Iterate over the list using count.index
}

resource "aws_s3_bucket" "second_bucket" {
  for_each = var.bucket_names_set  # Iterate over the set

  bucket = each.value  # Access the value directly

  depends_on = [aws_s3_bucket.first_bucket]  # Explicit dependency on first_bucket
}
```

In this case, Terraform will provision `second_bucket` only after the `first_bucket` is successfully created.

---

## Assignment

1. **Create output to print all bucket names using a `for` loop**
2. **Create output to print all bucket IDs using a `for` expression**

### Resource Definition

```hcl
resource "aws_s3_bucket" "bucket_collection_using_for_each" {
  for_each = toset(var.bucket_names)  # Iterate over the list of bucket names
  bucket   = each.value
  tags = {
    Environment = "Dev"
  }
}
```

### Output to Print All Bucket Names Using a `for` Loop

```hcl
output "bucket_names_using_for" {
  value = [for bucket in aws_s3_bucket.bucket_collection_using_for_each : bucket.bucket]
}
```

### Explanation:

- The `for` loop iterates over each bucket in the `bucket_collection_using_for_each` and extracts the `bucket` name.

### Output to Print All Bucket IDs Using a `for` Expression

```hcl
output "bucket_ids_using_for_expression" {
  value = [for bucket in aws_s3_bucket.bucket_collection_using_for_each : bucket.id]
}
```

### Explanation:

- The `for` expression iterates over each bucket in the `bucket_collection_using_for_each` and extracts the `id` of each bucket.

---

### Full Example (Including Both Outputs):

```hcl
resource "aws_s3_bucket" "bucket_collection_using_for_each" {
  for_each = toset(var.bucket_names)  # Iterate over the list of bucket names
  bucket   = each.value
  tags = {
    Environment = "Dev"
  }
}

output "bucket_names_using_for" {
  value = [for bucket in aws_s3_bucket.bucket_collection_using_for_each : bucket.bucket]
}

output "bucket_ids_using_for_expression" {
  value = [for bucket in aws_s3_bucket.bucket_collection_using_for_each : bucket.id]
}
```
