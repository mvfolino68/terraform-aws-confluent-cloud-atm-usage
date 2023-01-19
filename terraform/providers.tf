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
provider "confluent" {
  cloud_api_key    = "<cc environment admin key>"    # optionally use CONFLUENT_CLOUD_API_KEY env var
  cloud_api_secret = "<cc environment admin secret>" # optionally use CONFLUENT_CLOUD_API_SECRET env var
}
#Define the default provider (no alias defined):

provider "aws" {
  region  = "us-east-2"
}

#Define alternate aliased providers:

provider "aws" {
  region  = "us-east-1"
  alias   = "useast1"
}
