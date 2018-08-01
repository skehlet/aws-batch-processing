#!/bin/bash
set -e

#
# You must create the s3 bucket and dynamodb table before running this.
#

ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
REGION=us-west-2

terraform init \
	-backend-config="region=${REGION}" \
	-backend-config="bucket=${ACCOUNT_ID}-terraform-state-${REGION}" \
	-backend-config="key=aws-batch-processing.tfstate"
