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

locals {
  account_id = "${data.aws_caller_identity.current.account_id}"
}


resource "aws_s3_bucket" "batch_processing_incoming" {
  bucket = "${local.account_id}-batch-processing-incoming-${var.aws_region}"
  acl    = "private"
}



resource "aws_sns_topic" "batch_processing_incoming" {
  name = "batch_processing_incoming"
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
       }
   ]
}
EOF
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
  environment {
    variables = {
      AWS_REGION_NAME = "${var.aws_region}"
    }
  }
}










# resource "aws_dynamodb_table" "dynamodb_reports_table" {
#   name           = "reports${var.instance}"
#   read_capacity  = 5
#   write_capacity = 5
#   hash_key       = "id"
#   attribute {
#     name = "id"
#     type = "S"
#   }
# }


# resource "aws_s3_bucket_policy" "website_policy" {
#   bucket = "${aws_s3_bucket.website.id}"
#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#       {
#           "Sid": "PublicReadGetObject",
#           "Effect": "Allow",
#           "Principal": "*",
#           "Action": [
#               "s3:GetObject"
#           ],
#           "Resource": [
#               "${aws_s3_bucket.website.arn}/*"
#           ]
#       }
#   ]
# }
# EOF
# }

# resource "aws_s3_bucket_object" "website_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "styles.css"
#   source = "resources/s3_website/styles.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/styles.css"))}"
# }

# //==============================================
# //zest stuff

# //css

# resource "aws_s3_bucket_object" "bootstrap_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "bootstrap.css"
#   source = "resources/s3_website/zest/styles/bootstrap.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/bootstrap.css"))}"
# }

# resource "aws_s3_bucket_object" "docs_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "docs.css"
#   source = "resources/s3_website/zest/styles/docs.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/docs.css"))}"
# }

# resource "aws_s3_bucket_object" "github_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "github.css"
#   source = "resources/s3_website/zest/styles/github.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/github.css"))}"
# }

# resource "aws_s3_bucket_object" "prettify_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "prettify.min.css"
#   source = "resources/s3_website/zest/styles/prettify.min.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/prettify.min.css"))}"
# }

# resource "aws_s3_bucket_object" "runnableExample_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "runnableExample.css"
#   source = "resources/s3_website/zest/styles/runnableExample.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/runnableExample.css"))}"
# }

# resource "aws_s3_bucket_object" "runnableExampleInclude_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "runnableExampleInclude.css"
#   source = "resources/s3_website/zest/styles/runnableExampleInclude.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/runnableExampleInclude.css"))}"
# }

# resource "aws_s3_bucket_object" "zest_docs_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "zest-docs.css"
#   source = "resources/s3_website/zest/styles/zest-docs.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/zest-docs.css"))}"
# }

# resource "aws_s3_bucket_object" "zest_styles_css" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "zestLite.css"
#   source = "resources/s3_website/zest/styles/zestLite.css"
#   content_type = "text/css"
#   etag   = "${md5(file("resources/s3_website/zest/styles/zestLite.css"))}"
# }

# //fonts

# resource "aws_s3_bucket_object" "glyphicons_half_reg_eot_images2" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "glyphicons-halflings-regular.eot"
#   source = "resources/s3_website/zest/fonts/glyphicons-halflings-regular.eot"
#   content_type = "application/vnd.ms-fontobject"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/glyphicons-halflings-regular.eot"))}"
# }

# resource "aws_s3_bucket_object" "glyphicons_half_reg_svg_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "glyphicons-halflings-regular.svg"
#   source = "resources/s3_website/zest/fonts/glyphicons-halflings-regular.svg"
#   content_type = "image/svg+xml"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/glyphicons-halflings-regular.svg"))}"
# }

# resource "aws_s3_bucket_object" "glyphicons_half_reg_ttf_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "glyphicons-halflings-regular.ttf"
#   source = "resources/s3_website/zest/fonts/glyphicons-halflings-regular.ttf"
#   content_type = "application/font-sfnt"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/glyphicons-halflings-regular.ttf"))}"
# }

# resource "aws_s3_bucket_object" "glyphicons_half_reg_woff_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "glyphicons-halflings-regular.woff"
#   source = "resources/s3_website/zest/fonts/glyphicons-halflings-regular.woff"
#   content_type = "application/font-woff"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/glyphicons-halflings-regular.woff"))}"
# }

# resource "aws_s3_bucket_object" "glyphicons_half_reg_eot_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "glyphicons-halflings-regular.eot"
#   source = "resources/s3_website/zest/fonts/glyphicons-halflings-regular.eot"
#   content_type = "application/vnd.ms-fontobject"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/glyphicons-halflings-regular.eot"))}"
# }

# resource "aws_s3_bucket_object" "icommon_eot_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "icomoon.eot"
#   source = "resources/s3_website/zest/fonts/icomoon.eot"
#   content_type = "application/vnd.ms-fontobject"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/icomoon.eot"))}"
# }

# resource "aws_s3_bucket_object" "icomoon_svg_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "icomoon.svg"
#   source = "resources/s3_website/zest/fonts/icomoon.svg"
#   content_type = "image/svg+xml"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/icomoon.svg"))}"
# }

# resource "aws_s3_bucket_object" "icomoon_ttf_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "icomoon.ttf"
#   source = "resources/s3_website/zest/fonts/icomoon.ttf"
#   content_type = "application/font-sfnt"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/icomoon.ttf"))}"
# }

# resource "aws_s3_bucket_object" "icomoon_woff_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "icomoon.woff"
#   source = "resources/s3_website/zest/fonts/icomoon.woff"
#   content_type = "application/font-woff"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/icomoon.woff"))}"
# }

# resource "aws_s3_bucket_object" "sourcesSansPro_ital_ttf_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "SourceSansPro-Italic.ttf"
#   source = "resources/s3_website/zest/fonts/SourceSansPro-Italic.ttf"
#   content_type = "application/font-sfnt"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/SourceSansPro-Italic.ttf"))}"
# }

# resource "aws_s3_bucket_object" "sourcesSansPro_light_ttf_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "SourceSansPro-Light.ttf"
#   source = "resources/s3_website/zest/fonts/SourceSansPro-Light.ttf"
#   content_type = "application/font-sfnt"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/SourceSansPro-Light.ttf"))}"
# }

# resource "aws_s3_bucket_object" "sourcesSansPro_italLight_ttf_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "SourceSansPro-LightItalic.ttf"
#   source = "resources/s3_website/zest/fonts/SourceSansPro-LightItalic.ttf"
#   content_type = "application/font-sfnt"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/SourceSansPro-LightItalic.ttf"))}"
# }

# resource "aws_s3_bucket_object" "sourcesSansPro_reg_ttf_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "SourceSansPro-Regular.ttf"
#   source = "resources/s3_website/zest/fonts/SourceSansPro-Regular.ttf"
#   content_type = "application/font-sfnt"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/SourceSansPro-Regular.ttf"))}"
# }

# resource "aws_s3_bucket_object" "sourcesSansPro_semi_ttf_images" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "SourceSansPro-Semibold.ttf"
#   source = "resources/s3_website/zest/fonts/SourceSansPro-Semibold.ttf"
#   content_type = "application/font-sfnt"
#   etag   = "${md5(file("resources/s3_website/zest/fonts/SourceSansPro-Semibold.ttf"))}"
# }

# //scripts

# resource "aws_s3_bucket_object" "angularAnimate_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-animate.js"
#   source = "resources/s3_website/zest/js/angular-animate.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-animate.js"))}"
# }

# resource "aws_s3_bucket_object" "angularCookies_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-cookies.js"
#   source = "resources/s3_website/zest/js/angular-cookies.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-cookies.js"))}"
# }

# resource "aws_s3_bucket_object" "angularDragAndDrop_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-drag-and-drop-lists.js"
#   source = "resources/s3_website/zest/js/angular-drag-and-drop-lists.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-drag-and-drop-lists.js"))}"
# }

# resource "aws_s3_bucket_object" "angularLoader_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-loader.js"
#   source = "resources/s3_website/zest/js/angular-loader.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-loader.js"))}"
# }

# resource "aws_s3_bucket_object" "angularMessages_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-messages.js"
#   source = "resources/s3_website/zest/js/angular-messages.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-messages.js"))}"
# }

# resource "aws_s3_bucket_object" "angularMocks_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-mocks.js"
#   source = "resources/s3_website/zest/js/angular-mocks.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-mocks.js"))}"
# }

# resource "aws_s3_bucket_object" "angularResource_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-resource.js"
#   source = "resources/s3_website/zest/js/angular-resource.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-resource.js"))}"
# }

# resource "aws_s3_bucket_object" "angularRoute_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-route.js"
#   source = "resources/s3_website/zest/js/angular-route.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-route.js"))}"
# }

# resource "aws_s3_bucket_object" "angularSanitize_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-sanitize.js"
#   source = "resources/s3_website/zest/js/angular-sanitize.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-sanitize.js"))}"
# }

# resource "aws_s3_bucket_object" "angularScenario_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-scenario.js"
#   source = "resources/s3_website/zest/js/angular-scenario.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-scenario.js"))}"
# }

# resource "aws_s3_bucket_object" "angularTouch_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-touch.js"
#   source = "resources/s3_website/zest/js/angular-touch.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-touch.js"))}"
# }

# resource "aws_s3_bucket_object" "angularUiRouter_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular-ui-router.js"
#   source = "resources/s3_website/zest/js/angular-ui-router.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular-ui-router.js"))}"
# }

# resource "aws_s3_bucket_object" "angular_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "angular.js"
#   source = "resources/s3_website/zest/js/angular.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/angular.js"))}"
# }

# resource "aws_s3_bucket_object" "jqueryUi_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "jquery-ui.js"
#   source = "resources/s3_website/zest/js/jquery-ui.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/jquery-ui.js"))}"
# }

# resource "aws_s3_bucket_object" "jquery_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "jquery.js"
#   source = "resources/s3_website/zest/js/jquery.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/jquery.js"))}"
# }


# resource "aws_s3_bucket_object" "lodash_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "lodash.js"
#   source = "resources/s3_website/zest/js/lodash.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/lodash.js"))}"
# }

# resource "aws_s3_bucket_object" "moment_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "moment.js"
#   source = "resources/s3_website/zest/js/moment.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/moment.js"))}"
# }

# resource "aws_s3_bucket_object" "ngFileUpload_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "ng-file-upload.js"
#   source = "resources/s3_website/zest/js/ng-file-upload.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/ng-file-upload.js"))}"
# }

# resource "aws_s3_bucket_object" "preffify_css_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "prettify.min.css"
#   source = "resources/s3_website/zest/js/prettify.min.css"
#   content_type = "text/css"
#   etag = "${md5(file("resources/s3_website/zest/js/prettify.min.css"))}"
# }

# resource "aws_s3_bucket_object" "prettify_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "prettify.min.js"
#   source = "resources/s3_website/zest/js/prettify.min.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/prettify.min.js"))}"
# }

# resource "aws_s3_bucket_object" "raf_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "raf.js"
#   source = "resources/s3_website/zest/js/raf.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/raf.js"))}"
# }

# resource "aws_s3_bucket_object" "restangular_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "restangular.js"
#   source = "resources/s3_website/zest/js/restangular.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/restangular.js"))}"
# }

# resource "aws_s3_bucket_object" "run_prettify_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "run_prettify.min.js"
#   source = "resources/s3_website/zest/js/run_prettify.min.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/run_prettify.min.js"))}"
# }

# resource "aws_s3_bucket_object" "uiBoot_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "ui-bootstrap-tpls.min.js"
#   source = "resources/s3_website/zest/js/ui-bootstrap-tpls.min.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/ui-bootstrap-tpls.min.js"))}"
# }

# resource "aws_s3_bucket_object" "underscore_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "underscore.string.js"
#   source = "resources/s3_website/zest/js/underscore.string.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/underscore.string.js"))}"
# }

# resource "aws_s3_bucket_object" "zest_script" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key = "zestLite.js"
#   source = "resources/s3_website/zest/js/zestLite.js"
#   content_type = "application/javascript"
#   etag = "${md5(file("resources/s3_website/zest/js/zestLite.js"))}"
# }

# //===============================================

# data "template_file" "index_html" {
#   template = "${file("${path.cwd}/resources/s3_website/index.html")}"
#   vars {
#     api-gateway-url = "https://${aws_api_gateway_deployment.api_dev.rest_api_id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_deployment.api_dev.stage_name}"
#   }
# }

# resource "aws_s3_bucket_object" "website_index_html" {
#   bucket = "${aws_s3_bucket.website.bucket}"
#   key    = "index.html"
#   content = "${data.template_file.index_html.rendered}"
#   content_type = "text/html"
#   etag   = "${md5("${data.template_file.index_html.rendered}")}"
# }



# resource "aws_s3_bucket" "batch_incoming" {
#   bucket = "${local.account_id}-batch-incoming-${var.aws_region}"
#   acl    = "private"
# }

# resource "aws_s3_bucket_policy" "batch_incoming_policy" {
#   bucket = "${aws_s3_bucket.batch_incoming.id}"
#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#       {
#           "Sid": "PublicReadGetObject",
#           "Effect": "Allow",
#           "Principal": "*",
#           "Action": [
#               "s3:GetObject"
#           ],
#           "Resource": [
#               "${aws_s3_bucket.batch_incoming.arn}/*"
#           ]
#       }
#   ]
# }
# EOF
# }






# data "archive_file" "GenerateReportZip" {
#   type = "zip"
#   source_dir = "${var.lambda_function_generate_report_dir}"
#   output_path = ".tmp/generate_report.zip"
# }

# resource "aws_lambda_function" "GenerateReport" {
#   filename         = "${data.archive_file.GenerateReportZip.output_path}"
#   source_code_hash = "${base64sha256(file("${data.archive_file.GenerateReportZip.output_path}"))}"
#   function_name    = "GenerateReport${var.instance}"
#   role             = "${aws_iam_role.lambda_pgbadger_role.arn}"
#   handler          = "generate_report.handler"
#   runtime          = "nodejs6.10"
#   memory_size      = 512
#   timeout          = 60
#   publish          = true
#   environment {
#     variables = {
#       AWS_REGION_NAME = "${var.aws_region}"
#       DB_TABLE_NAME = "${aws_dynamodb_table.dynamodb_reports_table.name}"
#       BUCKET_NAME = "${aws_s3_bucket.batch_incoming.bucket}"
#       DBInstanceIdentifier = "${var.rds_db_name}"
#     }
#   }
# }

# resource "aws_lambda_permission" "with_sns" {
#   statement_id = "AllowExecutionFromSNS"
#   action = "lambda:InvokeFunction"
#   function_name = "${aws_lambda_function.GenerateReport.function_name}"
#   principal = "sns.amazonaws.com"
#   source_arn = "${aws_sns_topic.generate_new_report.arn}"
# }

# resource "aws_sns_topic_subscription" "lambda" {
#   topic_arn = "${aws_sns_topic.generate_new_report.arn}"
#   protocol  = "lambda"
#   endpoint  = "${aws_lambda_function.GenerateReport.arn}"
# }

# data "archive_file" "RetrievePgBadgerReportZip" {
#   type = "zip"
#   source_file = "${var.lambda_function_retrieve_report}"
#   output_path = ".tmp/retrieve_report.zip"
# }

# resource "aws_lambda_function" "RetrieveReport" {
#   filename         = "${data.archive_file.RetrievePgBadgerReportZip.output_path}"
#   source_code_hash = "${base64sha256(file("${data.archive_file.RetrievePgBadgerReportZip.output_path}"))}"
#   function_name    = "RetrieveReport${var.instance}"
#   role             = "${aws_iam_role.lambda_pgbadger_role.arn}"
#   handler          = "retrieve_report.handler"
#   runtime          = "nodejs6.10"
#   timeout          = 30
#   publish          = true
#   environment {
#     variables = {
#       AWS_REGION_NAME = "${var.aws_region}"
#       DB_TABLE_NAME = "${aws_dynamodb_table.dynamodb_reports_table.name}"
#     }
#   }
# }


# resource "aws_api_gateway_rest_api" "api" {
#   name = "PgBadgerReportAPI${var.instance}"
# }

# // No aws_api_gateway_resource instances since we're putting our methods on the root

# resource "aws_api_gateway_method" "post" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "POST"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "post" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.post.http_method}"
#   integration_http_method = "POST" # invoking lambda is always a POST, independent of the http_method
#   type = "AWS"
#   uri = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.GenerateReportRequest.arn}/invocations"
# }

# resource "aws_lambda_permission" "allow_api_to_call_post_lambda" {
#   statement_id  = "AllowExecutionFromAPIGateway"
#   action        = "lambda:InvokeFunction"
#   function_name = "${aws_lambda_function.GenerateReportRequest.arn}"
#   principal     = "apigateway.amazonaws.com"
#   source_arn = "arn:aws:execute-api:${var.aws_region}:${local.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.post.http_method}/"
# }

# resource "aws_api_gateway_integration_response" "post" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.post.http_method}"
#   status_code = "${aws_api_gateway_method_response.post.status_code}"
#   depends_on  = ["aws_api_gateway_integration.post"]
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin" = "'*'"
#   }
#   response_templates {
#     "application/json" = ""
#   }
# }

# resource "aws_api_gateway_method_response" "post" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.post.http_method}"
#   status_code = "200"
#   response_models = {
#     "application/json" = "Empty"
#   }
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin" = true
#   }
# }

# resource "aws_api_gateway_method" "get" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "GET"
#   authorization = "NONE"
#   depends_on  = ["aws_api_gateway_method.post"] # hacky workaround to create methods one at a time to avoid ConflictExceptions
#   request_parameters = {
#     "method.request.querystring.id" = false # false means optional
#   }
# }

# resource "aws_api_gateway_integration" "get" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.get.http_method}"
#   integration_http_method = "POST" # invoking lambda is always a POST, independent of the http_method
#   type = "AWS"
#   uri = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.RetrieveReport.arn}/invocations"
#   request_templates = {
#     "application/json" = <<EOF
# {
#   "id": "$input.params('id')"
# }
# EOF
#   }
#   passthrough_behavior = "WHEN_NO_TEMPLATES"
# }

# resource "aws_lambda_permission" "allow_api_to_call_get_lambda" {
#   statement_id  = "AllowExecutionFromAPIGateway"
#   action        = "lambda:InvokeFunction"
#   function_name = "${aws_lambda_function.RetrieveReport.function_name}"
#   principal     = "apigateway.amazonaws.com"
#   source_arn = "arn:aws:execute-api:${var.aws_region}:${local.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.get.http_method}/"
# }

# resource "aws_api_gateway_integration_response" "get" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.get.http_method}"
#   status_code = "${aws_api_gateway_method_response.get.status_code}"
#   depends_on  = ["aws_api_gateway_integration.get"]
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin" = "'*'"
#   }
#   response_templates {
#     "application/json" = ""
#   }
# }

# resource "aws_api_gateway_method_response" "get" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.get.http_method}"
#   status_code = "200"
#   response_models = {
#     "application/json" = "Empty"
#   }
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin" = true
#   }
# }




# # CORS
# resource "aws_api_gateway_method" "options" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "OPTIONS"
#   authorization = "NONE"
#   depends_on  = ["aws_api_gateway_method.get"] # hacky workaround to create methods one at a time to avoid ConflictExceptions
# }

# resource "aws_api_gateway_integration" "options" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.options.http_method}"
#   type = "MOCK"
#   request_templates = {
#     "application/json" = <<EOF
# {"statusCode": 200}
# EOF
#   }
# }

# resource "aws_api_gateway_integration_response" "options" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.options.http_method}"
#   status_code = "${aws_api_gateway_method_response.options.status_code}"
#   depends_on  = ["aws_api_gateway_integration.options"]
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
#     "method.response.header.Access-Control-Allow-Methods" = "'POST,GET,OPTIONS'",
#     "method.response.header.Access-Control-Allow-Origin" = "'*'"
#   }
#   response_templates = {
#     "application/json" = ""
#   }
# }

# resource "aws_api_gateway_method_response" "options" {
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
#   http_method = "${aws_api_gateway_method.options.http_method}"
#   status_code = "200"
#   response_models = {
#     "application/json" = "Empty"
#   }
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = true,
#     "method.response.header.Access-Control-Allow-Methods" = true,
#     "method.response.header.Access-Control-Allow-Origin" = true
#   }
# }

# resource "aws_api_gateway_deployment" "api_dev" {
#   depends_on = [
#     "aws_api_gateway_method.post",
#     "aws_api_gateway_integration.post",
#     "aws_api_gateway_integration_response.post",
#     "aws_api_gateway_method_response.post",
#     "aws_api_gateway_method.get",
#     "aws_api_gateway_integration.get",
#     "aws_api_gateway_integration_response.get",
#     "aws_api_gateway_method_response.get",
#     "aws_api_gateway_method.options",
#     "aws_api_gateway_integration.options",
#     "aws_api_gateway_integration_response.options",
#     "aws_api_gateway_method_response.options"
#   ]
#   rest_api_id = "${aws_api_gateway_rest_api.api.id}"
#   stage_name = "dev"
#   # This never seems to run, so we force it to run every time. This is an undesirable workaround.
#   # See: https://github.com/hashicorp/terraform/issues/6613#issuecomment-289797226
#   description = "Deployed at ${timestamp()}"
# }

# output "website_endpoint" {
#   value = "http://${aws_s3_bucket.website.website_endpoint}"
# }
