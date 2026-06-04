# ---------------------------------------------------------------------------
# Remote State — S3 + DynamoDB
#
# Before running terraform init for the first time on a new client account:
#   1. Create the S3 bucket:   aws s3api create-bucket --bucket <bucket> --region <region>
#   2. Enable versioning:      aws s3api put-bucket-versioning ...
#   3. Create DynamoDB table:  aws dynamodb create-table --table-name terraform-state-lock ...
#      (partition key: LockID, type: S)
#
# The bootstrap script will inject the correct values below before opening the PR.
# ---------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "{{TF_STATE_BUCKET}}"
    key            = "{{CLIENT_NAME}}/terraform.tfstate"
    region         = "{{AWS_REGION}}"
    dynamodb_table = "{{TF_STATE_LOCK_TABLE}}"
    encrypt        = true
  }
}
