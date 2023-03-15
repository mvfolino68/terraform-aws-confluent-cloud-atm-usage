# Terraform Template for AWS and Confluent Cloud Resources

Example Terraform template for provisioning AWS and Confluent Cloud resources for atm-fraud demo.

## Before you get started

Before you get started, you're going to need a few things.

- Terraform
  - Install Terraform by following the instructions [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).
- Confluent Cloud account
  - Sign up for a [Confluent Cloud](https://confluent.cloud/) account.
- AWS account
  - Sign up for an [AWS](https://aws.amazon.com/) account.
- Confluent Cloud **Cloud API Key & Secret**
  - Create Confluent Cloud API Key & Secret by following the instructions [here](https://docs.confluent.io/cloud/current/access-management/authenticate/api-keys/api-keys.html#create-a-cloud-api-key). You will need to create a new API Key and Secret for this demo or use an existing one. Terraform will use these credentials to create the resources in Confluent Cloud and will prompt you when you run `terraform apply` for the values.
- MongoDB Atlas
  - Create a MongoDB Atlas cluster by following the instructions [here](https://docs.atlas.mongodb.com/tutorial/deploy-free-tier-cluster/). You will need to create a new cluster for this demo or use an existing one.
- AWS CLI and AWS credentials
  - Install the AWS CLI by following the instructions [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).
  - Configure the AWS CLI by following the instructions [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html).

If you don't have these things, create and collect them. **Make sure to create resources in us-east-1.**

## Getting started

To begin, the absolute first thing you'll need to do is clone this repo.

```bash
git clone git@github.com:mvfolino68/terraform-aws-confluent-cloud-atm-usage.git && cd terraform-aws-confluent-cloud-atm-usag
```

## Provisioning almost everything

Provisioning should be easy. This example is meant to create an **almost** end-to-end setup of components in AWS and Confluent Cloud (still waiting on the Ksql Query part). To provision everything follow the next few steps.

Initialize Terraform in the `/terraform` directory.

```bash
terraform init
```

Create a plan.

```bash
terraform plan
```

Apply the whole thing!

```bash
terraform apply -auto-approve
```

> **_Note:_** _the `-auto-approve` flag automagically accepts the implicit plan created by `apply`_.

Give your configuration some time to create. When it's done, head to the Confluent UI and check out what was provisioned.

## Ksql queries

To create the streaming topology, paste the following into you Ksql editor. **Be sure to set `auto.offset.reset` to `earliest`!**

see `ksql.sql` for more details

Once everything has been created, go check out Stream Lineage to see your topology in action.

## MongoDB Connector (Not automated yet)

When you have the MongoDB Atlas cluster created, you can create the connector to connect to it. These are example parameters for the connector.

1. In CC cluster `Add MongoDB Atlas Sink connector`
   1. hostname: `cluster0.xprwruk.mongodb.net`
   2. connection user: `mongodbuser`
   3. password: `abcABC123`
   4. database: `dev`
   5. collection: `atm_fraud`
   6. schema: `json sr`

## Cleanup

Once you're satisfied with what you've built, do ahead and destroy it.

```bash
terraform destroy
```

## Storage Issue with Free Tier

Allowing this to continue to run will incur charges or consume all of the free tier. To avoid this, you can destroy the resources that exceed free tier or are not free tier eligible. You can reapply the resources that are free tier eligible when you're ready to continue.

```bash
terraform destroy -target=confluent_connector.postgres_cdc_atm \
-target=aws_vpc.main \
-target=aws_subnet.public_subnets \
-target=aws_internet_gateway.igw \
-target=aws_route_table.route_table \
-target=aws_security_group.postgres_sg \
-target=random_id.atm_id \
-target=cloudinit_config.pg_bootstrap_atm \
-target=aws_instance.postgres_atm \
-target=aws_eip.postgres_atm_eip
```
