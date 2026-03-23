terraform {
  backend "s3" {
    bucket         = "dev-setup-state"
    key            = "global/dev-stack.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "dev-setup-lock"
    encrypt        = true
  }
}
