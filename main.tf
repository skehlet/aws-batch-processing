terraform {
  required_version = ">= 0.10.6"

  backend "s3" {
    # region, bucket, and key configured via init.sh
    dynamodb_table = "terraform-state"
  }
}

provider "aws" {
  region  = "us-west-2"
  version = "~> 1.26"
}

data "aws_caller_identity" "current" {}

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
  subnet_ids = ["${aws_subnet.private1.id}"]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "batch-processing"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  port                 = 6379
  num_cache_nodes      = 1
  parameter_group_name = "default.redis4.0"
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
  runtime          = "nodejs8.10"
  timeout          = 60
  publish          = true
  vpc_config       = {
    subnet_ids = ["${aws_subnet.private1.id}"]
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


resource "aws_iam_role" "batch_processing_worker_role" {
  name = "batch-processing-worker"
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

resource "aws_iam_role_policy" "batch_processing_worker_role_policy1" {
  name = "batch-processing-worker-role-policy1"
  role = "${aws_iam_role.batch_processing_worker_role.id}"
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
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:ChangeMessageVisibility"
          ],
          "Resource": "${aws_sqs_queue.batch_processing_queue.arn}"
       },
       {
          "Effect": "Allow",
          "Action": [
            "lambda:InvokeFunction"
          ],
          "Resource": "arn:aws:lambda:us-west-2:${local.account_id}:function:queue-worker"
       }
   ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "worker_attachment" {
  role = "${aws_iam_role.batch_processing_worker_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "batch_processing_worker_zip" {
  type = "zip"
  source_dir = "queue-worker"
  output_path = ".tmp/queue-worker.zip"
}

resource "aws_lambda_function" "queue_worker" {
  filename         = "${data.archive_file.batch_processing_worker_zip.output_path}"
  source_code_hash = "${base64sha256(file("${data.archive_file.batch_processing_worker_zip.output_path}"))}"
  function_name    = "queue-worker"
  role             = "${aws_iam_role.batch_processing_worker_role.arn}"
  handler          = "index.handler"
  runtime          = "nodejs8.10"
  timeout          = 60
  publish          = true
  vpc_config       = {
    subnet_ids = ["${aws_subnet.private1.id}"]
    security_group_ids = ["${aws_security_group.allow_anything.id}"]
  }
  environment {
    variables = {
      AWS_REGION_NAME = "${var.aws_region}"
      SQS_QUEUE_URL = "${aws_sqs_queue.batch_processing_queue.id}"
      REDIS_HOST = "${aws_elasticache_cluster.redis.cache_nodes.0.address}"
      REDIS_PORT = "${aws_elasticache_cluster.redis.port}"
      S3_INCOMING_BUCKET = "${aws_s3_bucket.batch_processing_incoming.id}"
      S3_OUTGOING_BUCKET = "${aws_s3_bucket.batch_processing_outgoing.id}"
    }
  }
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  batch_size        = 10
  event_source_arn  = "${aws_sqs_queue.batch_processing_queue.arn}"
  enabled           = true
  function_name     = "${aws_lambda_function.queue_worker.arn}"
}
