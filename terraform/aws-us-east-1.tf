resource "random_id" "vpc_display_id" {
    byte_length = 4
}
# ------------------------------------------------------
# VPC
# ------------------------------------------------------
resource "aws_vpc" "main" { 
    cidr_block = "10.0.0.0/16"
    provider = aws
    tags = {
        Name = "atm-usage-vpc-main-${random_id.vpc_display_id.hex}"
    }
}
# ------------------------------------------------------
# SUBNETS
# ------------------------------------------------------
resource "aws_subnet" "public_subnets" {
    count = 3
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.${count.index+1}.0/24"
    map_public_ip_on_launch = true
    tags = {
        Name = "atm-usage-public-subnet-${count.index}-${random_id.vpc_display_id.hex}"
    }
    provider = aws

}
# ------------------------------------------------------
# IGW
# ------------------------------------------------------
resource "aws_internet_gateway" "igw" { 
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "atm-usage-igw-${random_id.vpc_display_id.hex}"
    }
    provider = aws

}
# ------------------------------------------------------
# ROUTE TABLE
# ------------------------------------------------------
resource "aws_route_table" "route_table" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "atm-usage-route-table-${random_id.vpc_display_id.hex}"
    }
    provider = aws
}
resource "aws_route_table_association" "subnet_associations" {
    count = 3
    subnet_id = aws_subnet.public_subnets[count.index].id
    route_table_id = aws_route_table.route_table.id
    provider = aws

}
# ------------------------------------------------------
# SECURITY GROUP
# ------------------------------------------------------
resource "aws_security_group" "postgres_sg" {
    name = "postgres_security_group_${random_id.vpc_display_id.hex}"
    description = "${local.aws_description}"
    vpc_id = aws_vpc.main.id
    egress {
        description = "Allow all outbound."
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    ingress {
        description = "Postgres"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    tags = {
        Name = "atm-usage-postgres-sg-${random_id.vpc_display_id.hex}"
    }
    provider = aws
}
# ------------------------------------------------------
# ATM ID AND CLOUDINIT
# ------------------------------------------------------
resource "random_id" "atm_id" {
    count = local.num_postgres_instances
    byte_length = 4
}
data "cloudinit_config" "pg_bootstrap_atm" {
    base64_encode = true
    part {
        content_type = "text/x-shellscript"
        content = "${file("scripts/pg_atm_bootstrap.sh")}"
    }
}
# ------------------------------------------------------
# ATM INSTANCE
# ------------------------------------------------------
resource "aws_instance" "postgres_atm" {
    count = local.num_postgres_instances
    ami = "ami-03ededff12e34e59e"
    instance_type = local.postgres_instance_shape
    subnet_id = aws_subnet.public_subnets[1].id
    vpc_security_group_ids = ["${aws_security_group.postgres_sg.id}"]
    user_data = "${data.cloudinit_config.pg_bootstrap_atm.rendered}"
    tags = {
        Name = "atm-usage-postgres-atm-instance-${random_id.atm_id[count.index].hex}"
    }
    provider = aws
}
# ------------------------------------------------------
# ATM EIP
# ------------------------------------------------------
resource "aws_eip" "postgres_atm_eip" {
    count = local.num_postgres_instances
    vpc = true
    instance = aws_instance.postgres_atm[count.index].id
    provider = aws
    tags = {
        Name = "atm-usage-postgres-atm-eip-${random_id.atm_id[count.index].hex}"
    }
}
