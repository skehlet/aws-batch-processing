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

resource "aws_api_gateway_deployment" "api_dev" {
  depends_on = [
    "aws_api_gateway_method.post",
    "aws_api_gateway_integration.post",
    "aws_api_gateway_integration_response.post",
    "aws_api_gateway_method_response.post"
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
