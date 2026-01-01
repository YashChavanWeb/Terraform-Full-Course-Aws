# Create bucket for Terraform state
aws s3 mb s3://yash-chavan-web-new-bucket-day-27 --region us-east-1

# Enable versioning for state history
aws s3api put-bucket-versioning \
  --bucket yash-chavan-web-new-bucket-day-27 \
  --versioning-configuration Status=Enabled
  

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket yash-chavan-web-new-bucket-day-27 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'