echo off

set ACCOUNT_ID=519765885403
set REGION=us-west-2
set TERRAFORM_EXE=%HOMEPATH%\Downloads\terraform.exe

rem You must create the bucket and dynamodb table before running this.

%TERRAFORM_EXE% init ^
	-backend-config="region=us-west-2" ^
	-backend-config="bucket=%ACCOUNT_ID%-terraform-state-%REGION%" ^
	-backend-config="key=aws-batch-processing.tfstate"
