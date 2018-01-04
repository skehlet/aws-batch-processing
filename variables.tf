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
