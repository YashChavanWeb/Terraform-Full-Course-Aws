# S3 bucket for static website hosting
resource "aws_s3_bucket" "my-website" {
  bucket = var.bucket_name
}

# Making the S3 bucket private
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.my-website.id   # implicit dependency

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin access control
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "demo-oac-${var.bucket_name}"
  description                       = "OAC for static website"
  origin_access_control_origin_type = "s3"   # s3 as we are doing for bucket
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket Policy
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.my-website.id

  # Explicit dependency (using resource name, not attribute)
  depends_on = [aws_s3_bucket_public_access_block.block]

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowCloudFrontServicePrincipal",
        "Effect": "Allow",
        "Principal": {
          "Service": "cloudfront.amazonaws.com"
        },
        "Action": [
          "s3:GetObject"
        ],
        "Resource": "${aws_s3_bucket.my-website.arn}/*",   # access all the objects inside that bucket
        "Condition": {
          "StringEquals": {
            "AWS:SourceArn": "${aws_cloudfront_distribution.s3_distribution.arn}"   # reference to CloudFront distribution
          }
        }
      }
    ]
  })
}

# Upload the file
resource "aws_s3_object" "object" {
  # Get all the files - html, css, js
  for_each = fileset("${path.module}/www", "**/*")
  bucket   = aws_s3_bucket.my-website.id
  key      = each.value
  source   = "${path.module}/www/${each.value}"

  etag = filemd5("${path.module}/www/${each.value}")  # unique hash

  # Lookup for accepting only certain files based on extension
  # Fixed: Use regex to properly extract file extension
  content_type = lookup({
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "jpeg" = "image/jpeg"
    "png"  = "image/png"
    "gif"  = "image/gif"
    "svg"  = "image/svg+xml"
    "ico"  = "image/x-icon"
    "jpg"  = "image/jpeg"
    "txt"  = "text/plain"
    "json" = "application/json"
    "xml"  = "application/xml"
    "pdf"  = "application/pdf"
  }, regex("\\.[^.]+$", each.value) != null ? replace(regex("\\.[^.]+$", each.value), ".", "") : "txt", "application/octet-stream")
}

# ACM Certificate for HTTPS (must be in us-east-1 for CloudFront)
resource "aws_acm_certificate" "cert" {
  count             = var.create_route53_record && var.domain_name != "" ? 1 : 0
  provider          = aws.us-east-1  # CloudFront requires certificates in us-east-1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = ["www.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.domain_name}-cert"
  }
}

# Route 53 record for ACM certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_route53_record && var.domain_name != "" ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# ACM Certificate validation
resource "aws_acm_certificate_validation" "cert" {
  count                   = var.create_route53_record && var.domain_name != "" ? 1 : 0
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Create a CloudFront distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.my-website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = local.origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Static website distribution"
  default_root_object = "index.html"
  aliases             = var.create_route53_record && var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.create_route53_record && var.domain_name != "" ? false : true
    acm_certificate_arn            = var.create_route53_record && var.domain_name != "" ? aws_acm_certificate.cert[0].arn : null
    ssl_support_method             = var.create_route53_record && var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version       = var.create_route53_record && var.domain_name != "" ? "TLSv1.2_2021" : null
  }

  depends_on = [aws_acm_certificate_validation.cert]
}

# Route 53 A record for the domain
resource "aws_route53_record" "website" {
  count   = var.create_route53_record && var.domain_name != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route 53 A record for www subdomain
resource "aws_route53_record" "website_www" {
  count   = var.create_route53_record && var.domain_name != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
