output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.test_backend.bucket
}

output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.main_vpc.id
}

output "ec2_instance_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.test_instance.public_ip
}
