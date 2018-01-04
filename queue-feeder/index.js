'use strict';

[
    'AWS_REGION_NAME',
    'SQS_QUEUE_URL',
    'REDIS_HOST',
    'REDIS_PORT',
    'MY_FUNCTION_NAME'
].forEach(function (varName) {
    if (!process.env[varName]) {
        console.error(`You must set the ${varName} environment variable`);
        process.exit(1);
    }
});

const AWS_REGION_NAME = process.env.AWS_REGION_NAME;
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;
const REDIS_HOST = process.env.REDIS_HOST;
const REDIS_PORT = process.env.REDIS_PORT;
const MY_FUNCTION_NAME = process.env.MY_FUNCTION_NAME;

const AWS = require('aws-sdk');
AWS.config.update({
    region: AWS_REGION_NAME
});
const SQS = new AWS.SQS({apiVersion: '2012-11-05'});
const Lambda = new AWS.Lambda({apiVersion: '2015-03-31'});
const redis = require('redis');
const Promise = require('bluebird');
Promise.promisifyAll(redis.RedisClient.prototype); // It'll add a Async to all node_redis functions (e.g. return client.getAsync().then())
Promise.promisifyAll(redis.Multi.prototype);

function notifyCaller(uuid) {
    const publisher = redis.createClient({
        host: REDIS_HOST,
        port: REDIS_PORT
    });
    console.log(`Trying to publish to redis for ${uuid}`);
    return publisher.publishAsync(uuid, "ready").then(function () {
        console.log(`published redis notification for ${uuid}`);
        // publisher.quit();
    });
}

function feed(msg) {
    console.log(`Hello, ${msg.Body} of message ID [${msg.MessageId}]`);
    console.log('full message:', JSON.stringify(msg, null, 4));
    const uuid = msg.MessageAttributes.uuid.StringValue;

    let delParams = {
        QueueUrl: SQS_QUEUE_URL,
        ReceiptHandle: msg.ReceiptHandle
    };
    return SQS
        .deleteMessage(delParams)
        .promise()
        .then(() => console.log(`Message ID [${msg.MessageId}] deleted`))
        .then(() => notifyCaller(uuid))
        .catch(err => console.log(`Message ID [${msg.MessageId}]`, err, err.stack));
}

function recurse() {
    let params = { 
        FunctionName: MY_FUNCTION_NAME,
        InvokeArgs: "{}"
    };

    return Lambda
        .invokeAsync(params)
        .promise()
        .then(() => console.log("Recursed."));
}

exports.handler = function(event, context) {
    let params = {
        QueueUrl            : SQS_QUEUE_URL,
        MaxNumberOfMessages : 10,
        VisibilityTimeout   : 6,
        WaitTimeSeconds     : 20,
        MessageAttributeNames: ["All"]
    };

    console.log('now long-polling SQS for messages...');
    SQS
        .receiveMessage(params)
        .promise()
        .then(res => {
            if (res.Messages) {
                console.log(`Now processing ${res.Messages.length} messages from SQS!`);
                return Promise.all(res.Messages.map(feed));
            }
        })
        // handle any errors and restore the chain so we always get
        // to the next step - which is to recurse
        .catch(err => console.log('ERROR :-(', err, err.stack))
        // .then(() => recurse()) // TODO: this is turned off until I implement a good way to stop it
        .then(function () {
            console.log('All done, now exiting');
            context.succeed();
        })
        // only fail the function if we couldn't recurse, which we
        // can then monitor via CloudWatch and trigger 
        .catch(err => context.fail(err, err.stack));
};