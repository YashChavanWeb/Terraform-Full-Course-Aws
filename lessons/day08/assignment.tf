# Task 1:

variable "bucket_names" {
    type = list(string)
    default = ["unique.yash.bucket-1", "unique.yash.bucket-2"]
}

resource "aws_s3_bucket" "bucket_collection_using_count" {
    count = 2
    bucket = "${var.bucket_names[count.index]}"
    # bucket = "${var.bucket_names[0]}"  --> if we want to do individually
    tags = {
        Environment = "Dev"
    }
}

resource "aws_s3_bucket" "bucket_collection_using_for_each" {
    for_each = toset(var.bucket_names)
    bucket = each.value
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