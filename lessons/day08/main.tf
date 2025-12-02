resource "aws_s3_bucket" "first_bucket" {
  count = 2  # this is no of resources created
  
    #   hardcoded
    #   bucket = bucket_names[0]

    # using count
    bucket = bucket_names[count.index]   # iterations will take place with all the names


}


resource "aws_s3_bucket" "second_bucket" {
  for_each = var.bucket_names_set  # this is no of times we want to run the for each
#   we can also give it a count for_each = 3

  bucket = each.value # directly access the value

    # here we have added the dependency
    depends_on = [aws_s3_bucket.first_bucket]
}

