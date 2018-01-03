resource "aws_api_gateway_rest_api" "api" {
  name = "batch-processing"
}

// No aws_api_gateway_resource instances since we're putting our methods on the root

resource "aws_api_gateway_method" "post" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"
  integration_http_method = "POST" # invoking lambda is always a POST, independent of the http_method
  type = "AWS"
  uri = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.batch_processing_post.arn}/invocations"
}

resource "aws_lambda_permission" "allow_api_to_call_post_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.batch_processing_post.arn}"
  principal     = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${var.aws_region}:${local.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.post.http_method}/"
}

resource "aws_api_gateway_integration_response" "post" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"
  status_code = "${aws_api_gateway_method_response.post.status_code}"
  depends_on  = ["aws_api_gateway_integration.post"]
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  response_templates {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method_response" "post" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

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

resource "aws_api_gateway_deployment" "api_dev" {
  depends_on = [
    "aws_api_gateway_method.post",
    "aws_api_gateway_integration.post",
    "aws_api_gateway_integration_response.post",
    "aws_api_gateway_method_response.post",
    # "aws_api_gateway_method.get",
    # "aws_api_gateway_integration.get",
    # "aws_api_gateway_integration_response.get",
    # "aws_api_gateway_method_response.get",
    # "aws_api_gateway_method.options",
    # "aws_api_gateway_integration.options",
    # "aws_api_gateway_integration_response.options",
    # "aws_api_gateway_method_response.options"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name = "dev"
  # This never seems to run, so we force it to run every time. This is an undesirable workaround.
  # See: https://github.com/hashicorp/terraform/issues/6613#issuecomment-289797226
  description = "Deployed at ${timestamp()}"
}

output "api_endpoint" {
  # value = "http://${aws_s3_bucket.website.website_endpoint}"
  value = "${aws_api_gateway_deployment.api_dev.invoke_url}"
}
