[
    'AWS_REGION_NAME',
    'SQS_QUEUE_URL',
    'REDIS_HOST',
    'REDIS_PORT'
].forEach(function (varName) {
    if (!process.env[varName]) {
        console.error(`You must set the ${varName} environment variable`);
        process.exit(1);
    }
});

const AWS_REGION_NAME = process.env.AWS_REGION_NAME;
// const SNS_INCOMING_TOPIC = process.env.SNS_INCOMING_TOPIC;
// const SNS_PROCESSED_TOPIC = process.env.SNS_PROCESSED_TOPIC;
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;
const REDIS_HOST = process.env.REDIS_HOST;
const REDIS_PORT = process.env.REDIS_PORT;
const AWS = require('aws-sdk');
AWS.config.update({
    region: AWS_REGION_NAME
});
// const SNS = new AWS.SNS({apiVersion: '2010-03-31'});
const SQS = new AWS.SQS({apiVersion: '2012-11-05'});
const Promise = require('bluebird');
const uuidv4 = require('uuid/v4');
const redis = require('redis');
Promise.promisifyAll(redis.RedisClient.prototype); // It'll add a Async to all node_redis functions (e.g. return client.getAsync().then())
Promise.promisifyAll(redis.Multi.prototype);

exports.handler = function (event, context, callback) {
    console.log('Event:', JSON.stringify(event, null, 4));

    // generate a uuid
    const uuid = uuidv4();
    console.log('uuid:', uuid);

    Promise.try(function () {
        // use it to store the request in s3
        // TBD, but not necessary right now, just to try this out
        console.log('storing message in S3 (not really)');
        return;

    }).then(function () {
        // subscribe to the "response topic"
        // return SNS.
        // TODO: THIS IS NOT POSSIBLE

        // subscribe to redis pubsub
        console.log(`subscribing to redis pubsub ${uuid}`);
        return new Promise(function (resolve) {
            const subscriber = redis.createClient({
                host: REDIS_HOST,
                port: REDIS_PORT
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
        // // emit an sns event that triggers the other lambda. in that event, include the uuid
        // return SNS.publish({
        //     TopicArn: SnsTopic,
        //     Message: id
        // }).promise();

        // enqueue the data into sqs. in the data, include the uuid
        console.log(`enqueuing the data into SQS`);
        let params = {
            QueueUrl: SQS_QUEUE_URL,
            MessageBody: 'TBD-some-path-on-s3',
             MessageAttributes: {
                "uuid": {
                    DataType: "String",
                    StringValue: uuid
                }
            }
        };
        return SQS.sendMessage(params).promise();

    }).then(function () {
        console.log('now just sitting and waiting for a redis pubsub before I invoke the callback');
    }).catch(function (err) {
        console.log('ERROR:', err);
        callback(err);
    });
};
