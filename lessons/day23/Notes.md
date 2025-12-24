# End to End Observability in AWS using Terraform

## Project Breakdown:

1.  Deploying a serverless application
2.  Adding Observability to the serverless application

### 1. Deploying a serverless application

#### The Application

- User uploads file to the S3 bucket.
- This file upload will trigger an event to the Lambda function.
- It will start processing using the lambda function script.
- Convert the uploaded image in different formats, and it will be uploaded to the new S3 bucket.

### 2. Adding Observability to the serverless application

- Adding Proactive logging, monitoring, alerting and logging.
- This lambda function will emit some metrics - CPU, Memory.
- All of these metrics will be published to CloudWatch.
- There will be log stream and log group where the logs will be published.
- Custom metrics will be created by adding filters, etc. also those will be published to cloud watch.
- And also we will have dashboard with widgets where these can be monitored.
- Based on these logs, some thresholds will be evaluated.
- And based on these thresholds, some alarms will be triggered which will send the notifications.
- These notifications will be sent to different SNS Topics - CriticalSNS, PerformanceSNS, LogAlertSNS.
- And all these notifications will be delivered to the users.

> **Note:** Everything will be created using custom modules.

## Terraform Modules

### 1. Root Module

It will be having some basic things like random prefix, and locals for having variables of bucket_prefix, name, etc.
Now we also have a lambda layer - which will be having the pillow function for image processing.

```hcl
resource "aws_lambda_layer_version" "pillow_layer" {
  filename            = "${path.module}/pillow_layer.zip"
  layer_name          = "${var.project_name}-pillow-layer"
  compatible_runtimes = ["python3.12"]
  description         = "Pillow library for image processing"
}

# Data source for Lambda function zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}
```

And then we can start with the actual modules.

1.  **SNS notifications** - we are using modules and so require the source.

    ```hcl
    module "sns_notifications" {
      source = "./modules/sns_notifications"

      project_name            = var.project_name
      environment             = var.environment
      critical_alert_email    = var.alert_email
      performance_alert_email = var.alert_email
      log_alert_email         = var.alert_email
      critical_alert_sms      = var.alert_sms

      tags = local.common_tags
    }
    ```

### 2. SNS Module

Creates SNS topics and subscriptions for different alert types.

> **Note:** A topic is a communication channel to which messages are sent, and a subscription is an endpoint (like an email) that receives those messages from the topic.

**Example:**

```hcl
resource "aws_sns_topic" "critical_alerts" {
  name         = "${var.project_name}-${var.environment}-critical-alerts"
  display_name = "Critical Lambda Alerts - ${var.project_name}"

  tags = merge(
    var.tags,
    {
      Name      = "${var.project_name}-critical-alerts"
      AlertType = "Critical"
    }
  )
}
```

In the same way we can create topics for the other two.
And then after this we create an email subscription for this.

```hcl
# Email subscription for Critical Alerts
resource "aws_sns_topic_subscription" "critical_email" {
  count     = var.critical_alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.critical_alert_email
}
```

The count is set to 1, meaning the subscription will be created. If it's empty, the count is set to 0, and no subscription will be created.

> **Note:** You can also use an SMS protocol for sending the SMS.

After we have created the topic and subscription, we can create the topic policy so this policy will allow CloudWatch to publish the notifications to the SNS topics.

```hcl
resource "aws_sns_topic_policy" "critical_alerts_policy" {
  arn = aws_sns_topic.critical_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.critical_alerts.arn
      }
    ]
  })
}
```

Now next in the root module we are using the S3 buckets module that we have created. We are just passing the variables and that can be used by the module imported.

**Example of the data shared from root module:**

```hcl
module "s3_buckets" {
  source = "./modules/s3_buckets"

  upload_bucket_name    = local.upload_bucket_name
  processed_bucket_name = local.processed_bucket_name
  environment           = var.environment
  enable_versioning     = var.enable_s3_versioning

  tags = local.common_tags
}
```

### 3. S3 Buckets

- Here some basic steps are used and resources are created for the buckets.
  1.  Creating the bucket.
  2.  Adding the versioning to it.
  3.  Server side encryption - using AES 256 algorithm.
  4.  Disabling public access block.

Now for the Lambda function custom module, we are sharing a lot of variables:

- `function_name`, `handler`, `timeout`, `memory_size`, `layers = []`, etc.
- And also pass on the bucket ARNs and IDs.
- And finally the basic details of log retention days and log level.

### 4. Lambda Function

Firstly we are creating an IAM role and IAM policy for the lambda function.

```hcl
resource "aws_iam_role" "lambda_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        ...
      }
    ]
  })
}
```

And then we create its policy, for creating the log groups, log streams and log events.

```hcl
# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.upload_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.processed_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}
```

Then we create the CloudWatch log group for the Lambda.

```hcl
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.function_name}-logs"
    }
  )
}
```

And finally we create the Lambda function with role, runtime, handler, etc. information and also make it as a dependency.

```hcl
depends_on = [
  aws_cloudwatch_log_group.lambda_log_group,
  aws_iam_role_policy.lambda_policy
]
```

#### Permission

Now we need to create a permission for S3 to invoke the Lambda function. Simply create a resource of `aws_lambda_permission` that will allow execution from S3 to invoke the Lambda function.

#### Notification Trigger

We have to create an S3 bucket notification to trigger Lambda. So it is also a resource of `aws_s3_bucket_notification` with some basic details like bucket and the Lambda function details.

```hcl
resource "aws_s3_bucket_notification" "upload_trigger" {
  bucket = module.s3_buckets.upload_bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_function.function_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
```

First we create the CloudWatch metrics in which we have to create a namespace, and then give the Lambda function name, log group, etc. Also we can enable the dashboard. This is also a module that we are using with these variables.

```hcl
module "cloudwatch_metrics" {
  source = "./modules/cloudwatch_metrics"

  function_name    = module.lambda_function.function_name
  log_group_name   = module.lambda_function.log_group_name
  metric_namespace = var.metric_namespace
  aws_region       = var.aws_region
  enable_dashboard = var.enable_cloudwatch_dashboard

  tags = local.common_tags
}
```

### 5. CloudWatch

Now for the resources created in CloudWatch, so firstly we have to create different filters in order to store the metrics.

```hcl
resource "aws_cloudwatch_log_metric_filter" "lambda_errors" {
  name           = "${var.function_name}-error-count"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, request_id, level = ERROR*, ...]"

  metric_transformation {
    name          = "LambdaErrors"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
  }
}
```

It filters logs based on a pattern looking for entries with `level = ERROR*`. When errors are detected, it triggers a custom metric (`LambdaErrors`) in the specified namespace with a value of `1`. The value: This helps CloudWatch track and visualize the count of Lambda errors over time by transforming the log data into a numerical metric.

Also we can create different filters using the same resource, `aws_cloudwatch_log_metric_filter` but with different patterns and metric transformations.

**Example:** Filtering the metrics based on processing time.

```hcl
  pattern        = "[timestamp, request_id, level, message, processing_time_key = \"processing_time:\", processing_time, ...]"

  metric_transformation {
    name          = "ImageProcessingTime"
    namespace     = var.metric_namespace
    value         = "$processing_time"
    unit          = "Milliseconds"
    default_value = "0"
  }
```

In the same way just by changing these two values, we can have others as well success count. Can have other filters as image size, access denied, etc.

Now finally we are creating a CloudWatch dashboard for Lambda monitoring.
In the dashboard, we have dashboard body - whose JSON can be written with properties.

```hcl
resource "aws_cloudwatch_dashboard" "lambda_monitoring" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "${var.function_name}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Total Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Errors" }],
            [".", "Throttles", { stat = "Sum", label = "Throttles" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Invocations & Errors"
          period  = 300
          dimensions = {
            FunctionName = var.function_name
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
```

Properties like - `period` (after what time to refresh), `view`, etc. and `dimensions`. So we have to give the widget dimensions using the width, height and coordinates. In the same way other widgets as well. There are a lot of widgets to refer so we can refer it from:

### [Click here to view the code](https://github.com/piyushsachdeva/Terraform-Full-Course-Aws/blob/main/lessons/day23/aws-lamda-monitoring/terraform/modules/cloudwatch_metrics/main.tf)

Also one widget is of the type `log` which will stream the logs based on the query inserted.

```hcl
      {
        type = "log"
        properties = {
          query  = "SOURCE '${var.log_group_name}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20"
          region = var.aws_region
          title  = "Recent Errors"
        }
        width  = 24
        height = 6
        x      = 0
        y      = 18
      }
```

### 6. CloudWatch Alarms and Logs

So for the alarms we are again using the custom modules, and there are various fields for us to create, same for the log_alerts. Refer the documentation for reference:

> https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm

And also the entire code of the alarms is below:

### [Click here to view the code](https://github.com/piyushsachdeva/Terraform-Full-Course-Aws/blob/main/lessons/day23/aws-lamda-monitoring/terraform/modules/cloudwatch_alarms/main.tf)

**Simple example of a Lambda alarm:**

```hcl
# Alarm: Lambda Error Rate
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.function_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.error_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Triggers when Lambda function has more than ${var.error_threshold} errors"
  actions_enabled     = true
  alarm_actions       = [var.critical_alerts_topic_arn]
  ok_actions          = [var.critical_alerts_topic_arn]

  dimensions = {
    FunctionName = var.function_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-error-alarm"
      Severity = "Critical"
    }
  )
}
```

Similarly we are creating other alarms as well. You can refer the log alerts part here:

### [Click here to view the log alerts](https://github.com/piyushsachdeva/Terraform-Full-Course-Aws/blob/main/lessons/day23/aws-lamda-monitoring/terraform/modules/log_alerts/main.tf)

## Testing

First ensure you have AWS CLI, and then start your Docker. Running will create a Docker layer, and build the pillow layer. Then we also need the `tfvars` file having all the required variables. Subscribe to the notification tokens by going to the email.
