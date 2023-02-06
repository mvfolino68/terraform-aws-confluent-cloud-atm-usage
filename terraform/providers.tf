terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.46"
        }
        confluent = {
            source = "confluentinc/confluent"
            version = "1.23.0"
        }
    }
}
variable "CONFLUENT_CLOUD_API_KEY" {
    type        = string
    description = "Env Admin key"
}
variable "CONFLUENT_CLOUD_API_SECRET" {
    type        = string
    description = "Env Admin secret"
}
provider "confluent" {
  cloud_api_key    = var.CONFLUENT_CLOUD_API_KEY
  cloud_api_secret = var.CONFLUENT_CLOUD_API_SECRET
}
#Define the default provider (no alias defined):

provider "aws" {
  region  = "us-east-1"
}
