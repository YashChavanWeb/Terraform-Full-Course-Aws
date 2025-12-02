locals {
  s3_bucket_name = "${var.bucket_name}-${random_string.bucket_suffix.result}"
  vpc_name       = "main-vpc-${var.environment}"
  ec2_instance_name = "test-instance-${var.environment}"
}