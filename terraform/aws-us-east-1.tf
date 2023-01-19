resource "random_id" "vpc_display_id_useast1" {
    byte_length = 4
}
# ------------------------------------------------------
# VPC
# ------------------------------------------------------
resource "aws_vpc" "main_useast1" { 
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "gko-case-vpc-main-${random_id.vpc_display_id_useast1.hex}"
    }
    provider = aws.useast1

}
# ------------------------------------------------------
# SUBNETS
# ------------------------------------------------------
resource "aws_subnet" "public_subnets_useast1" {
    count = 3
    vpc_id = aws_vpc.main_useast1.id
    cidr_block = "10.0.${count.index+1}.0/24"
    map_public_ip_on_launch = true
    tags = {
        Name = "gko-case-public-subnet-${count.index}-${random_id.vpc_display_id_useast1.hex}"
    }
    provider = aws.useast1
}
# ------------------------------------------------------
# IGW
# ------------------------------------------------------
resource "aws_internet_gateway" "igw_useast1" { 
    vpc_id = aws_vpc.main_useast1.id
    tags = {
        Name = "gko-case-igw-${random_id.vpc_display_id_useast1.hex}"
    }
    provider = aws.useast1
}
# ------------------------------------------------------
# ROUTE TABLE
# ------------------------------------------------------
resource "aws_route_table" "route_table_useast1" {
    vpc_id = aws_vpc.main_useast1.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw_useast1.id
    }
    tags = {
        Name = "gko-case-route-table-${random_id.vpc_display_id.hex}"
    }
    provider = aws.useast1
}
resource "aws_route_table_association" "subnet_associations_useast1" {
    count = 3
    subnet_id = aws_subnet.public_subnets_useast1[count.index].id
    route_table_id = aws_route_table.route_table_useast1.id
    provider = aws.useast1
}
# ------------------------------------------------------
# SECURITY GROUP
# ------------------------------------------------------
resource "aws_security_group" "postgres_sg_useast1" {
    name = "postgres_security_group_${random_id.vpc_display_id_useast1.hex}"
    description = "${local.aws_description}"
    vpc_id = aws_vpc.main_useast1.id
    provider = aws.useast1
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
        Name = "gko-case-postgres-sg-${random_id.vpc_display_id_useast1.hex}"
    }
}
# ------------------------------------------------------
# PRODUCTS ID AND CLOUDINIT
# ------------------------------------------------------
resource "random_id" "products_id_useast1" {
    count = local.num_postgres_instances
    byte_length = 4
}
data "cloudinit_config" "pg_bootstrap_products_useast1" {
    base64_encode = true
    part {
        content_type = "text/x-shellscript"
        content = "${file("scripts/pg_products_bootstrap.sh")}"
    }
}
# ------------------------------------------------------
# PRODUCTS INSTANCE
# ------------------------------------------------------
resource "aws_instance" "postgres_products_useast1" {
    count = local.num_postgres_instances
    ami = "ami-03ededff12e34e59e"
    instance_type = local.postgres_instance_shape
    subnet_id = aws_subnet.public_subnets_useast1[1].id
    vpc_security_group_ids = ["${aws_security_group.postgres_sg_useast1.id}"]
    user_data = "${data.cloudinit_config.pg_bootstrap_products_useast1.rendered}"
    provider = aws.useast1
    tags = {
        Name = "gko-case-postgres-products-instance-${random_id.products_id_useast1[count.index].hex}"
    }
}
# ------------------------------------------------------
# PRODUCTS EIP
# ------------------------------------------------------
resource "aws_eip" "postgres_products_eip_useast1" {
    count = local.num_postgres_instances
    vpc = true
    provider = aws.useast1
    instance = aws_instance.postgres_products_useast1[count.index].id
    tags = {
        Name = "gko-case-postgres-products-eip-${random_id.products_id_useast1[count.index].hex}"
    }
}
