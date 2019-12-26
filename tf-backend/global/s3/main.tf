provider "aws" {
  region = "eu-west-2"
  profile= "terraform"
}

# # Add S3 backend and DynamoDB lock
terraform {
  backend "s3" {
    # Bucket name
    bucket = "drazvt-terraform-state"
    key = "tf-backend/global/s3/terraform.tfstate"
    region = "eu-west-2"

    # DybamoDB table name
    dynamodb_table = "drazvt-terraform-locks"
    encrypt = true
    profile = "terraform"
  }
}

# Create S3 bucket for terraform state files
resource "aws_s3_bucket" "terraform_state" {
  # Bucket name, must pe globbaly unique
  bucket = "drazvt-terraform-state"

  # Enable revision so we can see the full revision history
  # of the state files
  versioning {
      enabled = true
  }

  # Enable server-side encryption by default
  server_side_encryption_configuration {
      rule {
          apply_server_side_encryption_by_default {
              sse_algorithm = "AES256"
          }
      }
  }
}

# Create DynamoDB table for terraform locks
resource "aws_dynamodb_table" "terraform_locks" {
  name = "drazvt-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
      name = "LockID"
      type = "S"
  }
}

