@echo off

for /f "delims=" %%i in ('aws sts get-caller-identity --output text --query Account') do set ACCOUNT_ID=%%i
set REGION=us-west-2
set TERRAFORM_EXE=%HOMEPATH%\Downloads\terraform.exe

rem You must create the s3 bucket and dynamodb table before running this.

%TERRAFORM_EXE% init ^
	-backend-config="region=us-west-2" ^
	-backend-config="bucket=%ACCOUNT_ID%-terraform-state-%REGION%" ^
	-backend-config="key=aws-batch-processing.tfstate"
