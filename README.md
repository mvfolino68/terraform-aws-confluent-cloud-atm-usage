# Terraform Template for AWS and Confluent Cloud Resources

Example Terraform template for provisioning AWS and Confluent Cloud resources for atm-fraud demo.

## Before you get started

Before you get started, you're going to need a few things.

- Terraform
- Confluent Cloud account
- AWS account
- Confluent Cloud **Cloud API Key & Secret**
- MongoDB Atlas
- AWS API Key & Secret (ideally with some kind of admin permission)

If you don't have these things, create and collect them. **Make sure to create resources in us-east-1.**

## Getting started

To begin, the absolute first thing you'll need to do is clone this repo.

```bash
git clone <repo name> && cd <repo name>
```

Next, you should create a secrets file to store you keys and secrets.

```bash
cat <<EOF > env.sh
export TF_VAR_CONFLUENT_CLOUD_API_KEY="<replace>"
export TF_VAR_CONFLUENT_CLOUD_API_SECRET="<replace>"
EOF
```

After copying your secrets into the file (replacing `<replace>`), you should export them to the console.

```bash
source env.sh
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
