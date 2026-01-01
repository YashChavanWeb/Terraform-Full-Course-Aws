# Image Processing Serverless Project

## How Lambda Works

- **Serverless**: The resources will be managed by AWS, and we just have to focus on the logic.
- The function will be triggered based on an event (e.g., file upload, server requests, etc.).
- If your code execution takes more than 15 minutes, then an EC2 instance is much more preferable.

## Project Overview

There are 2 S3 buckets:

1. When we upload a file to the source S3, the Lambda function will be triggered.
2. The function will process the files using a compression algorithm and then convert them to multiple formats.
3. These images will be stored in the destination bucket.
4. All logs will be uploaded to CloudWatch.

> **Basic Flow**: Upload image to source S3 → Lambda triggers → Processes → Saves to destination S3.

## Start

### Generating Random Suffixes

- Every time we create a resource, we need to create a unique name for it.

```hcl
resource "random_id" "suffix" {
  byte_length = 4
}
```

We can use this configuration:

```hcl
# random_id.suffix.hex
upload_bucket_name = "${local.bucket_prefix}-upload-${random_id.suffix.hex}"
```

### Creating the Bucket

- The bucket will require a lot of configuration for making it secure and production-ready.

```hcl
resource "aws_s3_bucket" "upload_bucket" {
  bucket = local.upload_bucket_name
}
```

- Now, we are enabling the bucket versioning. This helps in accessing the previous versions of the same file.

```hcl
resource "aws_s3_bucket_versioning" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

Optional: If you want to enable server-side encryption, we can do that as well using Terraform:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

If we want to make the bucket private, we need to make all the 4 options private. Here's the script for that:

```hcl
resource "aws_s3_bucket_public_access_block" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

In the same way, we can create the destination bucket as well, with all the same configurations:

```hcl
# S3 Bucket for processed images (DESTINATION)
resource "aws_s3_bucket" "processed_bucket" {
  bucket = local.processed_bucket_name
}
```

The rest of the options can be given in the same way as the upload bucket.

### Creating the Policies

- There is an AWS website for generating the policies:
  [AWS Policy Generator](https://awspolicygen.s3.amazonaws.com/policygen.html)

Using this website, we can create conditions, statements, and then get a JSON. This JSON can be used inside the resource to apply this policy:

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "${local.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    # policy json
  })
}
```

This is the IAM role assigned to the Lambda function.

- The assume role policy for Lambda means that we grant the Lambda function permission to take on the role's permissions.
- After creating this assume role policy, we can:

  - Assign permissions to Lambda.
  - The Lambda function can use this role to execute and perform actions.

Now, the main IAM policy for the Lambda function:

> **Note**: Earlier, we just assigned the role to the Lambda function, but here we are assigning the permissions to the role.

```hcl
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.lambda_function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Creating and adding the log groups to CloudWatch
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },

      # Getting the objects (images) from the S3 bucket
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.upload_bucket.arn}/*"
      },

      # Saving the processed images to the S3 bucket
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.processed_bucket.arn}/*"
      }
    ]
  })
}
```

These 3 policies will be assigned to the Lambda function. As soon as the image is uploaded to the source S3 bucket, the Lambda function will be triggered. With these permissions, it can perform all the required actions.

### Lambda Function Configuration

A Lambda layer is a .zip archive that contains libraries, dependencies, or custom code to be shared across multiple AWS Lambda functions. It is comparable to a virtual environment (venv) in Python. We just need to add basic information like runtimes and the files we are using.

```hcl
resource "aws_lambda_layer_version" "pillow_layer" {
  filename            = "${path.module}/pillow_layer.zip"
  layer_name          = "${var.project_name}-pillow-layer"
  compatible_runtimes = ["python3.12"]
  description         = "Pillow library for image processing"
}
```

After setting up the Lambda layer, we can define the Lambda function logic. But before that, we need a data source for the Lambda function (which will contain the Python script for processing):

```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"  # This is locally stored
  output_path = "${path.module}/lambda_function.zip"
}
```

Now we can simply create the Lambda function:

- `handler`: Defines the entry point for the Lambda function (`lambda_handler` in `lambda_function.py`).
- `source_code_hash`: Ensures that the function code is correctly packaged and checks for updates.
- `timeout`: Configures the maximum execution time of the function (60 seconds).
- `memory_size`: Allocates 1024 MB of memory for the function's execution.
- `layers`: Attaches the Pillow layer, providing the library for image processing.

```hcl
# Lambda function
resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 1024

  layers = [aws_lambda_layer_version.pillow_layer.arn]

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed_bucket.id
      LOG_LEVEL        = "INFO"
    }
  }
}
```

> **Note**: In the environment variables, we are passing the variables required for running the scripts.

So, the main steps for creating a Lambda function are:

1. Create a layer.
2. Have a script that will run (data source).
3. Create the Lambda function resource, combining all configurations.

Now, after creating the function, we also need to set up the configuration for CloudWatch (creating its resource):

```hcl
# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_processor" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 7
}
```

After the retention days, the logs will be cleared.

## Event Upload

Until now, we have set up the bucket configuration and Lambda function configuration. Now we need to set the trigger.

- The bucket should have permission to execute the Lambda function. For this, we need to create a permission resource.

```hcl
# Lambda permission to be invoked by S3
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn  # On which the trigger will be applied
}
```

This permission allows the Lambda function to be invoked by S3. Finally, after the image is processed and the object is created in the new S3, a notification will be given.

```hcl
# S3 bucket notification to trigger Lambda
resource "aws_s3_bucket_notification" "upload_bucket_notification" {
  bucket = aws_s3_bucket.upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3
```

:ObjectCreated:\*"]
}

depends_on = [aws_lambda_permission.allow_s3]
}

````

## Scripts

In large-scale projects, we need scripts to streamline the process. Here, we are using 3 scripts:

1. `build_layer.sh`
2. `deploy.sh`
3. `destroy.sh`

The code can be found in the respective files, but the main goal is to speed up the process of running commands and executing tasks.

Example of `deploy.sh`:

```bash
# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first."
    exit 1
fi

# Build Lambda layer
echo "📦 Building Lambda layer..."
chmod +x "$SCRIPT_DIR/build_layer.sh"
bash "$SCRIPT_DIR/build_layer.sh"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
cd "$PROJECT_DIR/terraform"
terraform init
````
