# Serverless batch processing experiment

For this experiment I wanted a solution for scalable batch processing using all AWS managed components.

Additionally, I wanted the response to the HTTP requester to be blocked until the processing was finished, so the client could be sure the processing succeeded and not have to turn around and poll us to be sure. This is a requirement of the clients I'm working with. Unfortunately, one limitation of API Gateway I was not aware of when I started is that requests cannot take longer than 29 seconds, and this cannot be increased by AWS. This could be a showstopper.

Once inside, I didn't want my lambda POST handler to have to poll S3 for the expected final product (although in hindsight that would be a much simpler solution), so I used Elasticache for Redis' [PUBLISH/SUBSCRIBE features](https://redis.io/topics/pubsub) to notify it that the backend lambda's work was done. This however required configuring the lambda functions to [be able to access resources in my VPC](https://docs.aws.amazon.com/lambda/latest/dg/vpc.html), which it can't normally do, and this comes with some special considerations:

* You tell lambda what subnet ids to run in, and then it creates ENIs on demand in one of those subnets.
* So you need enough free IPs, potentially up to a 1000 (the current lambda max simultaneous execution limit)
* When run this way, Lambdas no longer have Internet access (which includes reaching any AWS managed service like SQS), so you'll need to put them in a private subnet with its default route set to a NAT Gateway to get out. (I did look into VPC endpoints, and that could work, e.g. for S3, but seems like SQS is not supported, so you still need a NAT gateway).

My workers are going to want to access stuff inside my VPC like RDS, Redis, and Elasticsearch, so this would be necessary anyway.

*Update 2018-07-31*: Recently Lambda began [supporting SQS as an event source](https://aws.amazon.com/blogs/aws/aws-lambda-adds-amazon-simple-queue-service-to-supported-event-sources/), so this simplifies the lambda worker greatly! Previously I was using the recursive lambda technique from [theburningmonk.com](http://theburningmonk.com/2016/04/aws-lambda-use-recursive-function-to-process-sqs-messages-part-1/) to spawn an infinite chain of lambda executions.

Final notes:
* All the Terraform is included. Run `init.sh` (or `init.bat`) to initialize the state (stored on S3).
* cd into each of the lamda function directories (`batch-processing-post` and `queue-worker`) and run `npm install`.
* Run `terraform plan` and `terraform apply`.
* At the end of the `terraform apply` run, it will output your API Gateway URL
* POST to that URL like:
```
curl -vv https://abcds2v65i.execute-api.us-west-2.amazonaws.com/dev -d '{"message":"hi"}'
```
* I never actually implemented Step 6, writing something to S3.

![Batch processing using lambda](Batch%20processing%20using%20lambda.png)
