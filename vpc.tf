resource "aws_vpc" "batch" {
    cidr_block = "${var.vpc_cidr}"
    tags {
        Name = "batch"
    }    
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.batch.id}"
    tags {
        Name = "batch-igw"
    }
}

resource "aws_subnet" "public1" {
    vpc_id = "${aws_vpc.batch.id}"
    cidr_block = "${var.public1_subnet_cidr}"
    availability_zone = "${var.public1_subnet_az}"
    map_public_ip_on_launch = true
    tags {
        Name = "batch-${var.public1_subnet_az}-public-subnet"
        type = "public"
    }
}

resource "aws_route_table" "public1" {
    vpc_id = "${aws_vpc.batch.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }
    tags {
        Name = "batch-public-route-table"
    }
}

resource "aws_route_table_association" "public1" {
    subnet_id = "${aws_subnet.public1.id}"
    route_table_id = "${aws_route_table.public1.id}"
}

resource "aws_subnet" "private1" {
    vpc_id = "${aws_vpc.batch.id}"
    cidr_block = "${var.private1_subnet_cidr}"
    availability_zone = "${var.private1_subnet_az}"
    tags {
        Name = "batch-${var.private1_subnet_az}-private-subnet"
        type = "private"
    }
}

resource "aws_security_group" "nat_instance" {
    count = "${var.use_nat_gateway ? 0 : 1}"
    name        = "batch-nat-instance-sg"
    vpc_id      = "${aws_vpc.batch.id}"
    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${aws_subnet.private1.cidr_block}"]
    }
    tags {
        Name = "batch-nat-instance-sg"
    }
}

resource "aws_instance" "nat_instance" {
    count = "${var.use_nat_gateway ? 0 : 1}"
    ami = "${var.nat_instance_ami}"
    availability_zone = "${var.public1_subnet_az}"
    instance_type = "${var.nat_instance_type}"
    key_name = "${var.ssh_key_name}"
    vpc_security_group_ids = ["${aws_security_group.nat_instance.id}"]
    subnet_id = "${aws_subnet.public1.id}"
    associate_public_ip_address = true
    source_dest_check = false
    tags {
        Name = "batch-nat-instance"
    }
}

resource "aws_route_table" "private_nat_instance" {
    count = "${var.use_nat_gateway ? 0 : 1}"
    vpc_id = "${aws_vpc.batch.id}"
    route {
        cidr_block = "0.0.0.0/0"
        instance_id = "${aws_instance.nat_instance.id}"
    }
    tags {
        Name = "batch-private-route-table"
    }
}

resource "aws_route_table_association" "private_nat_instance" {
    count = "${var.use_nat_gateway ? 0 : 1}"
    subnet_id = "${aws_subnet.private1.id}"
    route_table_id = "${aws_route_table.private_nat_instance.id}"
}

resource "aws_cloudwatch_metric_alarm" "nat_recover" {
    count = "${var.use_nat_gateway ? 0 : 1}"
    alarm_name = "batch-nat-instance-recover"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "StatusCheckFailed_System"
    namespace = "AWS/EC2"
    period = "60"
    statistic = "Minimum"
    threshold = "0"
    alarm_actions = ["arn:aws:automate:${var.aws_region}:ec2:recover"]
    dimensions = {
        InstanceId = "${aws_instance.nat_instance.id}"
    }
    depends_on = ["aws_instance.nat_instance"]
}

resource "aws_eip" "eip1" {
    count = "${var.use_nat_gateway ? 1 : 0}"
    vpc = "true"
    tags {
        Name = "batch-nat-gw-eip"
    }
    depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "gw1" {
    count = "${var.use_nat_gateway ? 1 : 0}"
    allocation_id = "${aws_eip.eip1.id}"
    subnet_id     = "${aws_subnet.public1.id}"
    tags {
        Name = "batch-nat-gw"
    }
    depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_route_table" "private_nat_gw" {
    count = "${var.use_nat_gateway ? 1 : 0}"
    vpc_id = "${aws_vpc.batch.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.gw1.id}"
    }
    tags {
        Name = "batch-private-route-table"
    }
    depends_on = ["aws_nat_gateway.gw1"] // workaround for terraform consistency
}

resource "aws_route_table_association" "private_nat_gw" {
    count = "${var.use_nat_gateway ? 1 : 0}"
    subnet_id = "${aws_subnet.private1.id}"
    route_table_id = "${aws_route_table.private_nat_gw.id}"
}
