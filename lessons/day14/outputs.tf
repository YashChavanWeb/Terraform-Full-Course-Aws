# Output the S3 bucket name
output "s3_bucket_name" {
  value       = aws_s3_bucket.my-website.bucket
  description = "The name of the S3 bucket for static website hosting."
}

# Output the S3 bucket ARN
output "s3_bucket_arn" {
  value       = aws_s3_bucket.my-website.arn
  description = "The ARN of the S3 bucket."
}

# Output the CloudFront distribution URL
output "cloudfront_distribution_url" {
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
  description = "The URL of the CloudFront distribution that serves the S3 bucket content."
}

# Output the CloudFront distribution ARN
output "cloudfront_distribution_arn" {
  value       = aws_cloudfront_distribution.s3_distribution.arn
  description = "The ARN of the CloudFront distribution."
}

# Output the CloudFront distribution ID
output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.s3_distribution.id
  description = "The ID of the CloudFront distribution."
}

# Output the CloudFront OAC ID
output "cloudfront_oac_id" {
  value       = aws_cloudfront_origin_access_control.oac.id
  description = "The ID of the CloudFront Origin Access Control (OAC) for securing the connection to the S3 bucket."
}

# Output the CloudFront OAC name
output "cloudfront_oac_name" {
  value       = aws_cloudfront_origin_access_control.oac.name
  description = "The name of the CloudFront Origin Access Control (OAC)."
}

# Output the S3 bucket policy ARN (using bucket ARN and appending /policy)
output "s3_bucket_policy_arn" {
  value       = "${aws_s3_bucket.my-website.arn}/policy"  # Correct way to reference S3 bucket policy ARN
  description = "The ARN of the S3 bucket policy applied to allow CloudFront access."
}

# Output the ACM certificate ARN
output "acm_certificate_arn" {
  value       = var.create_route53_record && var.domain_name != "" ? aws_acm_certificate.cert[0].arn : "N/A - No domain configured"
  description = "The ARN of the ACM certificate for HTTPS."
}

# Output the custom domain URL
output "website_url" {
  value       = var.create_route53_record && var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
  description = "The URL to access the website."
}

# Output the Route 53 record name
output "route53_record" {
  value       = var.create_route53_record && var.domain_name != "" ? var.domain_name : "N/A - No domain configured"
  description = "The Route 53 DNS record for the website."
}
