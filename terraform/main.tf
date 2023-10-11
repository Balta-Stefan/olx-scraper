terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.19.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_iam_role" "olx-scraper-role" {
  name = "olx-scraper-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "olx-scraper-policy" {
  name = "olx-scraper-policy"
  role = aws_iam_role.olx-scraper-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "logs:CreateLogStream",
          "s3:DeleteObject",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:s3:::olx-scraper/*",
          "arn:aws:logs:*:*:log-group:*:log-stream:*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/olx-scraper:*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket" "olx-scraper-bucket" {
  bucket = "olx-scraper"

  tags = {
    Name = "Olx scraper bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket-ownership-controls" {
  bucket = aws_s3_bucket.olx-scraper-bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bucket-acl" {
  depends_on = [aws_s3_bucket_ownership_controls.bucket-ownership-controls]

  bucket = aws_s3_bucket.olx-scraper-bucket.id
  acl    = "private"
}

resource "aws_ssm_parameter" "gmail_api_credentials" {
  name = "/olx-scraper/gmail-api-credentials"
  type = "SecureString"
  value = file("../credentials.json")
}

resource "aws_lambda_function" "olx-scraper-lambda" {
  depends_on = [
    aws_s3_bucket.olx-scraper-bucket,
    aws_ssm_parameter.gmail_api_credentials
  ]

  function_name = "olx-scraper-lambda"
  role          = aws_iam_role.olx-scraper-role.arn
  image_uri = var.lambda_image_url
  package_type = "Image"
  timeout = "30"
  memory_size = "512"
  environment {
    variables = {
      RECEIVER = var.receiver_email
      LINKS_BUCKET = aws_s3_bucket.olx-scraper-bucket.bucket
      SCRAPE_URL = var.scrape_url
    }
  }
}