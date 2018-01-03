const AWS_REGION_NAME = process.env.AWS_REGION_NAME;
if (!AWS_REGION_NAME) {
    console.error('Set the AWS_REGION_NAME environment variable');
    process.exit(1);
}

const AWS = require('aws-sdk');
AWS.config.update({
    region: AWS_REGION_NAME
});

exports.handler = function (event, context, callback) {
    console.log('Event:', JSON.stringify(event, null, 4));

    callback(null, 'Hello from lambda in ' + AWS_REGION_NAME);
};
