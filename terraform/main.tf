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
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:s3:::olx-scraper/*",
          "arn:aws:logs:*:*:log-group:*:log-stream:*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/olx-scraper:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource =  "arn:aws:ssm:*:*:parameter/olx-scraper/*"
      }
    ]
  })
}

resource "aws_s3_bucket" "olx-scraper-bucket" {
  bucket = "olx-scraper"
  force_destroy = true

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

resource "null_resource" "get-gmail-token" {
  provisioner "local-exec" {
    command = <<-EOT
      cd ..
      venv/bin/python3 bootstrap_gmail_token.py
    EOT
  }
}

data "local_file" "token-file" {
  depends_on = [null_resource.get-gmail-token]

  filename = "../token.json"
}

resource "aws_ssm_parameter" "gmail_api_credentials" {
  depends_on = [data.local_file.token-file]

  name = "/olx-scraper/gmail-api-credentials"
  type = "SecureString"
  value = data.local_file.token-file.content #file("../token.json")
}

variable "lambda_function_name" {
  default = "olx-scraper-lambda"
}

resource "aws_lambda_function" "olx-scraper-lambda" {
  depends_on = [
    aws_s3_bucket.olx-scraper-bucket,
    aws_ssm_parameter.gmail_api_credentials,
    aws_cloudwatch_log_group.lambda_log_group
  ]

  function_name = var.lambda_function_name
  role          = aws_iam_role.olx-scraper-role.arn
  image_uri = var.lambda_image_url
  package_type = "Image"
  timeout = "30"
  memory_size = "1500"
  environment {
    variables = {
      RECEIVER = var.receiver_email
      LINKS_BUCKET = aws_s3_bucket.olx-scraper-bucket.bucket
      SCRAPE_URL = var.scrape_url
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 1
}

resource "aws_cloudwatch_event_rule" "scraper-schedule" {
  name = "olx-scraper-schedule"
  description = "Schedule for Lambda Function"
  schedule_expression = "cron(${var.lambda_cron_expression})"
}

resource "aws_cloudwatch_event_target" "schedule_lambda" {
  rule = aws_cloudwatch_event_rule.scraper-schedule.name
  arn = aws_lambda_function.olx-scraper-lambda.arn
}

resource "aws_lambda_permission" "allow_events_bridge_to_run_lambda" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.olx-scraper-lambda.function_name
  principal = "events.amazonaws.com"
}