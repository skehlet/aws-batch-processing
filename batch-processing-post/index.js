[
    'AWS_REGION_NAME',
    'SQS_QUEUE_URL',
    'REDIS_HOST',
    'REDIS_PORT',
    'S3_INCOMING_BUCKET'
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

const REDIS_CONNECT_TIMEOUT = 10 * 1000; // fail if we can't connect within 10sec, helps diagnose VPC problems
const REDIS_MAX_CONNECT_ATTEMPTS = 1; // helps diagnose VPC problems

const AWS = require('aws-sdk');
AWS.config.update({
    region: AWS_REGION_NAME
});
const SQS = new AWS.SQS({apiVersion: '2012-11-05'});
let s3 = new AWS.S3({
    signatureVersion: 'v4',
    apiVersion: '2006-03-01'
});
const Promise = require('bluebird');
const uuidv4 = require('uuid/v4');
const redis = require('redis');
Promise.promisifyAll(redis.RedisClient.prototype);
Promise.promisifyAll(redis.Multi.prototype);

exports.handler = function (event, context, callback) {
    const body = JSON.stringify(event, null, 4);
    console.log('Event:', body);

    // generate a uuid
    const uuid = uuidv4();
    console.log('uuid:', uuid);

    Promise.try(function () {
        // use the uuid to store the request in s3
        console.log('storing message in S3');
        let params = {
            Bucket: S3_INCOMING_BUCKET,
            Key: uuid,
            Body: body,
            ContentType: 'application/json'
        };
        return s3.upload(params).promise();

    }).then(function () {
        // subscribe to redis pubsub
        console.log(`subscribing to redis pubsub ${uuid}`);
        return new Promise(function (resolve) {
            const subscriber = redis.createClient({
                host: REDIS_HOST,
                port: REDIS_PORT,
                connect_timeout: REDIS_CONNECT_TIMEOUT,
                max_attempts: REDIS_MAX_CONNECT_ATTEMPTS
            });
            subscriber.on('subscribe', function (channel) {
                console.log(`successfully subscribed to redis pubsub channel ${channel}`);
                resolve();
            });
            // upon receiving a notice on the response topic with our uuid, complete this request
            subscriber.on('message', function (channel, message) {
                console.log(`received redis pubsub message for ${channel}, message: ${message}`);
                subscriber.unsubscribe();
                subscriber.quit();
                callback(null, `${uuid}: ${message}`);
            });
            console.log('about to subscribe to redis');
            subscriber.subscribe(uuid);
        });

    }).then(function () {
        // enqueue the data into SQS.
        console.log(`enqueuing the data into SQS`);
        let params = {
            QueueUrl: SQS_QUEUE_URL,
            MessageBody: uuid
        };
        return SQS.sendMessage(params).promise();

    }).then(function () {
        console.log('now just sitting and waiting for a redis pubsub before I invoke the callback');
    }).catch(function (err) {
        console.log('ERROR:', err);
        callback(err);
    });
};
