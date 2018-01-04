resource "aws_vpc" "batch" {
    cidr_block = "${var.vpc_cidr}"
    tags {
      Name = "batch"
    }    
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.batch.id}"
}

/*
  Public Subnet
*/
resource "aws_subnet" "public1" {
    vpc_id = "${aws_vpc.batch.id}"
    cidr_block = "${var.public1_subnet_cidr}"
    availability_zone = "${var.public1_subnet_az}"
    map_public_ip_on_launch = true
    tags {
        type = "public"
    }
}

resource "aws_route_table" "public1" {
    vpc_id = "${aws_vpc.batch.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }
}

resource "aws_route_table_association" "public1" {
    subnet_id = "${aws_subnet.public1.id}"
    route_table_id = "${aws_route_table.public1.id}"
}

/*
  Private Subnet
*/
resource "aws_subnet" "private1" {
    vpc_id = "${aws_vpc.batch.id}"
    cidr_block = "${var.private1_subnet_cidr}"
    availability_zone = "${var.private1_subnet_az}"
    tags {
        type = "private"
    }
}

resource "aws_route_table" "private1" {
    vpc_id = "${aws_vpc.batch.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.gw1.id}"
    }
    depends_on = ["aws_nat_gateway.gw1"] // workaround for terraform consistency
}

resource "aws_route_table_association" "private1" {
    subnet_id = "${aws_subnet.private1.id}"
    route_table_id = "${aws_route_table.private1.id}"
}

resource "aws_eip" "eip1" {
    vpc = "true"
    depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "gw1" {
  allocation_id = "${aws_eip.eip1.id}"
  subnet_id     = "${aws_subnet.public1.id}"
  depends_on = ["aws_internet_gateway.gw"]
}

