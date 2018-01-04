terraform {
  required_version = ">= 0.10.6"

  backend "s3" {
    # region, bucket, and key configured via init.sh
    dynamodb_table = "terraform-state"
  }
}

provider "aws" {
  region  = "us-west-2"
  version = "~> 1.0"
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc" {
  tags {
    Name = "${var.vpc_name}"
  }
}

data "aws_subnet_ids" "my_vpc_subnets" {
  vpc_id = "${data.aws_vpc.vpc.id}"
  # tags {
  #   type = "private"
  # }
}

locals {
  account_id = "${data.aws_caller_identity.current.account_id}"
}


resource "aws_s3_bucket" "batch_processing_incoming" {
  bucket = "${local.account_id}-batch-processing-incoming-${var.aws_region}"
  acl    = "private"
}


# resource "aws_sns_topic" "batch_processing_incoming" {
#   name = "batch_processing_incoming"
# }

resource "aws_security_group" "wide_open" {
  name        = "wide-open"
  description = "Allow anything"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] // TBD: should tighten this down
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"] // TBD: should tighten this down
  }
}

resource "aws_security_group" "redis" {
  name        = "redis"
  description = "Allow my VPC"
  # vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "batch-processing"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  port                 = 6379
  num_cache_nodes      = 1
  parameter_group_name = "default.redis3.2"
  apply_immediately    = true
  security_group_ids   = ["${aws_security_group.redis.id}"]
}


resource "aws_sqs_queue" "batch_processing_queue" {
  name                      = "batch-processing-queue"
  # delay_seconds             = 90
  # max_message_size          = 2048
  # message_retention_seconds = 86400
  receive_wait_time_seconds = 20
  visibility_timeout_seconds = 60
  # redrive_policy            = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.terraform_queue_deadletter.arn}\",\"maxReceiveCount\":4}"
}


resource "aws_iam_role" "batch_processing_post_role" {
  name = "batch-processing-handle-post"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "batch_processing_post_role_policy1" {
  name = "batch-processing-post-role-policy1"
  role = "${aws_iam_role.batch_processing_post_role.id}"
  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Effect": "Allow",
           "Action": [
              "sns:Publish",
              "s3:PutObject",
              "s3:GetBucketLocation",
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
           ],
           "Resource": [
               "*"
           ]
       },
       {
          "Effect": "Allow",
          "Action": [
            "sqs:SendMessage"
          ],
          "Resource": "${aws_sqs_queue.batch_processing_queue.arn}"
       }
   ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "post_attachment" {
  role = "${aws_iam_role.batch_processing_post_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "batch_processing_post_zip" {
  type = "zip"
  source_dir = "batch-processing-post"
  output_path = ".tmp/batch-processing-post.zip"
}

resource "aws_lambda_function" "batch_processing_post" {
  filename         = "${data.archive_file.batch_processing_post_zip.output_path}"
  source_code_hash = "${base64sha256(file("${data.archive_file.batch_processing_post_zip.output_path}"))}"
  function_name    = "batch-processing-post"
  role             = "${aws_iam_role.batch_processing_post_role.arn}"
  handler          = "index.handler"
  runtime          = "nodejs6.10"
  timeout          = 60
  publish          = true
  vpc_config       = {
    # subnet_ids = ["${data.aws_subnet_ids.my_vpc_subnets.ids}"]
    subnet_ids = ["subnet-e6e4e880"] // FIXME: hard-coded subnet for lambda with NAT gateway
    security_group_ids = ["${aws_security_group.wide_open.id}"]
  }
  environment {
    variables = {
      AWS_REGION_NAME = "${var.aws_region}"
      SQS_QUEUE_URL = "${aws_sqs_queue.batch_processing_queue.id}"
      REDIS_HOST = "${aws_elasticache_cluster.redis.cache_nodes.0.address}"
      REDIS_PORT = "${aws_elasticache_cluster.redis.port}"
    }
  }
}


resource "aws_iam_role" "batch_processing_feeder_role" {
  name = "batch-processing-feeder"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "batch_processing_feeder_role_policy1" {
  name = "batch-processing-feeder-role-policy1"
  role = "${aws_iam_role.batch_processing_feeder_role.id}"
  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Effect": "Allow",
           "Action": [
              "sns:Publish",
              "s3:GetObject",
              "s3:GetBucketLocation",
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
           ],
           "Resource": [
               "*"
           ]
       },
       {
          "Effect": "Allow",
          "Action": [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage"
          ],
          "Resource": "${aws_sqs_queue.batch_processing_queue.arn}"
       },
       {
          "Effect": "Allow",
          "Action": [
            "lambda:InvokeFunction"
          ],
          "Resource": "arn:aws:lambda:us-west-2:${local.account_id}:function:queue-feeder"
       }
   ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "feeder_attachment" {
  role = "${aws_iam_role.batch_processing_feeder_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "batch_processing_feeder_zip" {
  type = "zip"
  source_dir = "queue-feeder"
  output_path = ".tmp/queue-feeder.zip"
}

resource "aws_lambda_function" "queue_feeder" {
  filename         = "${data.archive_file.batch_processing_feeder_zip.output_path}"
  source_code_hash = "${base64sha256(file("${data.archive_file.batch_processing_feeder_zip.output_path}"))}"
  function_name    = "queue-feeder"
  role             = "${aws_iam_role.batch_processing_feeder_role.arn}"
  handler          = "index.handler"
  runtime          = "nodejs6.10"
  timeout          = 60
  publish          = true
  vpc_config       = {
    # subnet_ids = ["${data.aws_subnet_ids.my_vpc_subnets.ids}"]
    subnet_ids = ["subnet-e6e4e880"] // FIXME: hard-coded subnet for lambda with NAT gateway
    security_group_ids = ["${aws_security_group.wide_open.id}"]
  }
  environment {
    variables = {
      AWS_REGION_NAME = "${var.aws_region}"
      SQS_QUEUE_URL = "${aws_sqs_queue.batch_processing_queue.id}"
      REDIS_HOST = "${aws_elasticache_cluster.redis.cache_nodes.0.address}"
      REDIS_PORT = "${aws_elasticache_cluster.redis.port}"
      MY_FUNCTION_NAME = "queue-feeder"
    }
  }
}



