'use strict';

[
    'AWS_REGION_NAME',
    'SQS_QUEUE_URL',
    'REDIS_HOST',
    'REDIS_PORT',
    'S3_INCOMING_BUCKET',
    'S3_OUTGOING_BUCKET'
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
const S3_INCOMING_BUCKET = process.env.S3_INCOMING_BUCKET;
const S3_OUTGOING_BUCKET = process.env.S3_OUTGOING_BUCKET;

const REDIS_CONNECT_TIMEOUT = 10 * 1000; // fail if we can't connect within 10sec, helps diagnose VPC problems
const REDIS_MAX_CONNECT_ATTEMPTS = 1; // helps diagnose VPC problems

const AWS = require('aws-sdk');
AWS.config.update({
    region: AWS_REGION_NAME
});
let s3 = new AWS.S3({
    signatureVersion: 'v4',
    apiVersion: '2006-03-01'
});
const redis = require('redis');
const Promise = require('bluebird');
Promise.promisifyAll(redis.RedisClient.prototype);
Promise.promisifyAll(redis.Multi.prototype);

function notifyCallerWeAreDone(msg) {
    const uuid = msg.body;
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
    const uuid = msg.body;
    const params = {
        Bucket: S3_INCOMING_BUCKET,
        Key: uuid
    };
    return s3.deleteObject(params).promise().catch(function (err) {
        console.log('got error trying to delete object from s3:', err, 'params:', JSON.stringify(params, null, 4));
        throw err;
    });
}

function processRecord(record) {
    return Promise.try(function () {
        // console.log(`Hello, ${record.body} of message ID [${record.MessageId}]`);
        console.log('record:', JSON.stringify(record, null, 4));
        const uuid = record.body;

        return Promise.try(function () {
            // TODO: do some heavy processing here
            // e.g. process it text-to-speech and write to S3_OUTGOING_BUCKET
            // Or, invoke a new lambda function?
            // keep in mind we said we'd do it in 6 seconds, see VisibilityTimeout above
            console.log(`Now doing some heavy processing on object ${uuid}`);
        }).then(function () {
            return deleteIncomingObject(record);
        }).then(function () {
            return notifyCallerWeAreDone(record);
        });
    }).catch(err => console.log(`Message ID [${record.MessageId}]`, err, err.stack));
}

exports.handler = function(event) {
    const records = event.Records;
    console.log(`Now processing ${records.length} records from SQS`);
    return Promise.map(records, processRecord).catch(function (err) {
        console.log('ERROR:', err);
        throw err;
    });
};
