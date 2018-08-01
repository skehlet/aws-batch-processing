variable "aws_region" {
  default = "us-west-2"
}

variable "vpc_name" {
  default = "lambda-batch"
}

variable "vpc_cidr" {
  default = "10.128.0.0/16"
}

variable "public1_subnet_cidr" {
  default = "10.128.0.0/19"
}

variable "public1_subnet_az" {
  default = "us-west-2a"
}

variable "private1_subnet_cidr" {
  default = "10.128.128.0/19"
}

variable "private1_subnet_az" {
  default = "us-west-2a"
}

variable "use_nat_gateway" {
  description = "If set to true, use a NAT Gateway; else use a NAT instance (cheaper for non-performance-related testing)"
  default = false
}

variable "nat_instance_type" {
  description = "The instance type to use for the NAT instance (only used if use_nat_gateway is false)"
  default = "t2.micro"
}

variable "nat_instance_ami" {
  default = "ami-35d6664d" # amzn-ami-vpc-nat-hvm-2017.09.1.20180115-x86_64-ebs
}

variable "ssh_key_name" {}
