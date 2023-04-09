locals {
    aws_region = "us-east-1"
    aws_description = "AWS Resource created by Terraform"
    num_postgres_instances = 1
    postgres_instance_shape = "t2.micro"
    confluent_description = "Confluent Resource created by Terraform"
    user_email = "mfolino@confluent.io"
}
variable "CONFLUENT_CLOUD_API_KEY" {
    type        = string
    description = "Env Admin key"
}
variable "CONFLUENT_CLOUD_API_SECRET" {
    type        = string
    description = "Env Admin secret"
}
