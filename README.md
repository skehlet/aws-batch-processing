# Serverless batch processing experiment

For this experiment I wanted a solution for scalable batch processing using all AWS managed components.

Additionally, I wanted the response to the HTTP requester to be blocked until the processing was finished, so the client could be sure the processing succeeded and not have to turn around and poll us to be sure. This is a requirement of the clients I'm working with.

Once inside, I didn't want my lambda POST handler to have to poll S3 for the expected final product (although in hindsight that would be a much simpler solution), so I used Elasticache for Redis' [PUBLISH/SUBSCRIBE features](https://redis.io/topics/pubsub) to notify it that the backend lambda's work was done. This however required configuring the lambda functions to [be able to access resources in my VPC](https://docs.aws.amazon.com/lambda/latest/dg/vpc.html), which it can't normally do, and this comes with some special considerations:

* You tell lambda what subnet ids to run in, and then it creates ENIs on demand in one of those subnets.
* So you need enough free IPs, potentially up to a 1000 (the current lambda max simultaneous execution limit)
* When run this way, Lambdas no longer have Internet access (which includes reaching any AWS managed service like SQS), so you'll need to put them in a private subnet with its default route set to a NAT Gateway to get out. (I did look into VPC endpoints, and that could work, e.g. for S3, but seems like SQS is not supported, so you still need a NAT gateway).

I feel like this would be unappealing to some, but in my case, my workers are going to want to access stuff inside my VPC like RDS, Redis, and Elasticsearch, so this would be necessary anyway.

Next, regarding SQS: currently Lambda functions can't natively feed off or be triggered by SQS, but I stumbled across [a clever way from theburningmonk.com](http://theburningmonk.com/2016/04/aws-lambda-use-recursive-function-to-process-sqs-messages-part-1/) to spawn an infinite chain of lambda executions. He calls it recursive lambda, but I think of it as perpetual self-reexecution, because they don't stack up--just before exiting, you asynchronously launch a new instance of yourself. Each execution feeds off SQS using long-polling, up to the max wait time of 20 seconds. He has some math on the costs, and it's dirt cheap, even if you leave it running full time.

The next hurdle would be scaling, and [theburningmonk.com also has an article on scaling this automatically](https://medium.com/theburningmonk-com/aws-lambda-use-recursive-function-to-process-sqs-messages-part-2-28b488993d8e). Really cool, I hope to try it out soon.

Final notes:
* You have to kick off the recursive lambda function (see `launch-feeder.bat`), after which it'll keep going. For this experiment I have it look on S3 for an object named `keep-feeding`, and it only recurses if it finds it.
* All the Terraform is included. See `init.bat` to initialize the state on S3.
* You'll need to cd into each of the lamda function directories (`batch-processing-post` and `queue-feeder`) and run `npm install` before running the usual `terraform plan` and `terraform apply`.

![Batch processing using lambda](Batch%20processing%20using%20lambda.png)
