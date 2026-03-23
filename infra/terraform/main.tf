provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "state" {
  bucket = "dev-setup-state"
}

resource "aws_dynamodb_table" "lock" {
  name         = "dev-setup-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
