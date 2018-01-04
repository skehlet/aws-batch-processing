'use strict';

[
    'AWS_REGION_NAME',
    'SQS_QUEUE_URL',
    'REDIS_HOST',
    'REDIS_PORT',
    'S3_INCOMING_BUCKET',
    'S3_OUTGOING_BUCKET',
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
const S3_INCOMING_BUCKET = process.env.S3_INCOMING_BUCKET;
const S3_OUTGOING_BUCKET = process.env.S3_OUTGOING_BUCKET;

const REDIS_CONNECT_TIMEOUT = 10 * 1000; // fail if we can't connect within 10sec, helps diagnose VPC problems
const REDIS_MAX_CONNECT_ATTEMPTS = 1; // helps diagnose VPC problems

const S3_RECURSE_FLAG = 'keep-feeding';

const AWS = require('aws-sdk');
AWS.config.update({
    region: AWS_REGION_NAME
});
const SQS = new AWS.SQS({apiVersion: '2012-11-05'});
let s3 = new AWS.S3({
    signatureVersion: 'v4',
    apiVersion: '2006-03-01'
});
const Lambda = new AWS.Lambda({apiVersion: '2015-03-31'});
const redis = require('redis');
const Promise = require('bluebird');
Promise.promisifyAll(redis.RedisClient.prototype);
Promise.promisifyAll(redis.Multi.prototype);

function longPollSqs() {
    console.log('now long-polling SQS for messages...');
    let params = {
        QueueUrl            : SQS_QUEUE_URL,
        MaxNumberOfMessages : 10,
        VisibilityTimeout   : 6,
        WaitTimeSeconds     : 20
    };
    return SQS.receiveMessage(params).promise();
}

function handleSqsResponse(response) {
    if (!response.Messages) {
        console.log(`No messages to process.`);
        return;
    }        
    console.log(`Now processing ${response.Messages.length} messages from SQS`);
    return Promise.all(response.Messages.map(processMessage));
}

function deleteSqsMessage(msg) {
    let delParams = {
        QueueUrl: SQS_QUEUE_URL,
        ReceiptHandle: msg.ReceiptHandle
    };
    return SQS
        .deleteMessage(delParams)
        .promise()
        .then(() => console.log(`Message ID [${msg.MessageId}] deleted`));
}

function notifyCallerWeAreDone(msg) {
    const uuid = msg.Body;
    const publisher = redis.createClient({
        host: REDIS_HOST,
        port: REDIS_PORT,
        connect_timeout: REDIS_CONNECT_TIMEOUT,
        max_attempts: REDIS_MAX_CONNECT_ATTEMPTS
    });
    console.log(`Publishing redis notification for ${uuid}`);
    return publisher.publishAsync(uuid, "ready").then(function () {
        console.log(`published redis notification for ${uuid}`);
        return publisher.quitAsync();
    }).catch(function (err) { // swallow errors here, don't fail the whole processing
        console.log(`Message ID [${msg.MessageId}]`, err, err.stack)
    });
}

function deleteIncomingObject(msg) {
    const uuid = msg.Body;
    const params = {
        Bucket: S3_INCOMING_BUCKET,
        Key: uuid
    };
    return s3.deleteObject(params).promise().catch(function (err) {
        console.log('got error trying to delete object from s3:', err, 'params:', JSON.stringify(params, null, 4));
        throw err;
    });
}

function processMessage(msg) {
    return Promise.try(function () {
        // console.log(`Hello, ${msg.Body} of message ID [${msg.MessageId}]`);
        console.log('full message:', JSON.stringify(msg, null, 4));
        const uuid = msg.Body;

        return Promise.try(function () {
            // TODO: do some heavy processing here
            // e.g. process it text-to-speech and write to S3_OUTGOING_BUCKET
            // Or, invoke a new lambda function?
            // keep in mind we said we'd do it in 6 seconds, see VisibilityTimeout above
        }).then(() => deleteIncomingObject(msg))
        .then(() => deleteSqsMessage(msg))
        .then(() => notifyCallerWeAreDone(msg));
    }).catch(err => console.log(`Message ID [${msg.MessageId}]`, err, err.stack));
}

function shouldWeRecurse() {
    // we should, as long as the flag exists in s3
    var params = {
        Bucket: S3_INCOMING_BUCKET,
        Key: S3_RECURSE_FLAG
    };
    return s3.headObject(params).promise().then(function () {  
        return true;
    }).catch(function (err) {
        if (err.code === 'NotFound') {  
            return false;
        }
    });
}

function recurse() {
    return shouldWeRecurse()
        .then(function (answer) {
            if (!answer) {
                console.log('Not recursing, flag object not found in s3');
            } else {
                let params = { 
                    FunctionName: MY_FUNCTION_NAME,
                    InvokeArgs: "{}"
                };
                return Lambda
                    .invokeAsync(params)
                    .promise()
                    .then(() => console.log("Recursed.")); // I'd call it "self-perpetuating" instead of recursing
            }
        });
}

exports.handler = function(event, context) {
    longPollSqs()
        .then(handleSqsResponse)
        // handle any errors and restore the chain so we always get
        // to the next step - which is to recurse
        .catch(err => console.log('ERROR :-(', err, err.stack))
        .then(() => recurse())
        .then(function () {
            console.log('All done, now exiting');
            context.succeed();
        })
        // only fail the function if we couldn't recurse, which we
        // can then monitor via CloudWatch and trigger 
        .catch(err => context.fail(err, err.stack));
};