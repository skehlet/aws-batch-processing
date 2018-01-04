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

data "aws_subnet_ids" "private_subnets" {
  vpc_id = "${aws_vpc.batch.id}"
  tags {
    type = "private"
  }
}

locals {
  account_id = "${data.aws_caller_identity.current.account_id}"
}


resource "aws_s3_bucket" "batch_processing_incoming" {
  bucket = "${local.account_id}-batch-processing-incoming-${var.aws_region}"
  acl    = "private"
}

resource "aws_s3_bucket" "batch_processing_outgoing" {
  bucket = "${local.account_id}-batch-processing-outgoing-${var.aws_region}"
  acl    = "private"
}


resource "aws_security_group" "allow_anything" {
  name        = "wide-open"
  description = "Allow anything"
  vpc_id      = "${aws_vpc.batch.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redis" {
  name        = "redis"
  description = "Allow my VPC"
  vpc_id      = "${aws_vpc.batch.id}"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.batch.cidr_block}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_subnet_group" "private_subnets" {
  name       = "private-subnets-for-redis"
  subnet_ids = ["${data.aws_subnet_ids.private_subnets.ids}"]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "batch-processing"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  port                 = 6379
  num_cache_nodes      = 1
  parameter_group_name = "default.redis3.2"
  apply_immediately    = true
  subnet_group_name    = "${aws_elasticache_subnet_group.private_subnets.name}"
  security_group_ids   = ["${aws_security_group.redis.id}"]
}


resource "aws_sqs_queue" "batch_processing_queue" {
  name                      = "batch-processing-queue"
  receive_wait_time_seconds = 20
  visibility_timeout_seconds = 60
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
            "s3:PutObject"
          ],
          "Resource": "${aws_s3_bucket.batch_processing_incoming.arn}/*"
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
    subnet_ids = ["${data.aws_subnet_ids.private_subnets.ids}"]
    security_group_ids = ["${aws_security_group.allow_anything.id}"]
  }
  environment {
    variables = {
      AWS_REGION_NAME = "${var.aws_region}"
      SQS_QUEUE_URL = "${aws_sqs_queue.batch_processing_queue.id}"
      REDIS_HOST = "${aws_elasticache_cluster.redis.cache_nodes.0.address}"
      REDIS_PORT = "${aws_elasticache_cluster.redis.port}"
      S3_INCOMING_BUCKET = "${aws_s3_bucket.batch_processing_incoming.id}"
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
            "s3:GetObject",
            "s3:DeleteObject"
          ],
          "Resource": "${aws_s3_bucket.batch_processing_incoming.arn}/*"
       },
       {
          "Effect": "Allow",
          "Action": [
            "s3:PutObject"
          ],
          "Resource": "${aws_s3_bucket.batch_processing_outgoing.arn}/*"
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
    subnet_ids = ["${data.aws_subnet_ids.private_subnets.ids}"]
    security_group_ids = ["${aws_security_group.allow_anything.id}"]
  }
  environment {
    variables = {
      AWS_REGION_NAME = "${var.aws_region}"
      SQS_QUEUE_URL = "${aws_sqs_queue.batch_processing_queue.id}"
      REDIS_HOST = "${aws_elasticache_cluster.redis.cache_nodes.0.address}"
      REDIS_PORT = "${aws_elasticache_cluster.redis.port}"
      MY_FUNCTION_NAME = "queue-feeder"
      S3_INCOMING_BUCKET = "${aws_s3_bucket.batch_processing_incoming.id}"
      S3_OUTGOING_BUCKET = "${aws_s3_bucket.batch_processing_outgoing.id}"
    }
  }
}
