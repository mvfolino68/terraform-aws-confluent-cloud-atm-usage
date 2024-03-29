resource "random_id" "env_display_id" {
    byte_length = 4
}
# ------------------------------------------------------
# ENVIRONMENT (GLOBAL TO BOTH CLUSTERS)
# ------------------------------------------------------
resource "confluent_environment" "env" {
    display_name = "atm-usage-env-${random_id.env_display_id.hex}"
}
# ------------------------------------------------------
# SCHEMA REGISTRY
# ------------------------------------------------------
data "confluent_schema_registry_region" "sr_region" {
    cloud = "AWS"
    region = "${local.aws_region}"
    package = "ADVANCED"
}
resource "confluent_schema_registry_cluster" "sr" {
    package = data.confluent_schema_registry_region.sr_region.package
    environment {
        id = confluent_environment.env.id 
    }
    region {
        id = data.confluent_schema_registry_region.sr_region.id
    }
}
# ------------------------------------------------------
# KAFKA
# ------------------------------------------------------
resource "confluent_kafka_cluster" "basic" {
    display_name = "atm-usage-cluster${random_id.env_display_id.hex}"
    availability = "MULTI_ZONE"
    cloud = "AWS"
    region = "${local.aws_region}"
    standard {}
    environment {
        id = confluent_environment.env.id
    }
}
# ------------------------------------------------------
# SERVICE ACCOUNTS
# ------------------------------------------------------
resource "confluent_service_account" "app_manager" {
    display_name = "app-manager-sa-${random_id.env_display_id.hex}"
    description = "${local.confluent_description}"
}
resource "confluent_service_account" "ksql" {
    display_name = "ksql-${random_id.env_display_id.hex}"
    description = "${local.confluent_description}"
}
resource "confluent_service_account" "connectors" {
    display_name = "connector-sa-${random_id.env_display_id.hex}"
    description = "${local.confluent_description}"
}
# ------------------------------------------------------
# ROLE BINDINGS
# ------------------------------------------------------
resource "confluent_role_binding" "app_manager_env_admin" {
    principal = "User:${confluent_service_account.app_manager.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.env.resource_name
}
resource "confluent_role_binding" "ksql_cluster_admin" {
    principal = "User:${confluent_service_account.ksql.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}
resource "confluent_role_binding" "ksql_sr_resource_owner" {
    principal = "User:${confluent_service_account.ksql.id}"
    role_name = "ResourceOwner"
    crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sr.resource_name, "subject=*")
}
# ------------------------------------------------------
# ACLS
# ------------------------------------------------------
resource "confluent_kafka_acl" "connectors_source_acl_describe_cluster" {
    kafka_cluster {
        id = confluent_kafka_cluster.basic.id
    }
    resource_type = "CLUSTER"
    resource_name = "kafka-cluster"
    pattern_type = "LITERAL"
    principal = "User:${confluent_service_account.connectors.id}"
    operation = "DESCRIBE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys.id
        secret = confluent_api_key.app_manager_keys.secret
    }
}
resource "confluent_kafka_acl" "connectors_source_acl_create_topic" {
    kafka_cluster {
        id = confluent_kafka_cluster.basic.id
    }
    resource_type = "TOPIC"
    resource_name = "postgres"
    pattern_type = "PREFIXED"
    principal = "User:${confluent_service_account.connectors.id}"
    operation = "CREATE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys.id
        secret = confluent_api_key.app_manager_keys.secret
    }
}
resource "confluent_kafka_acl" "connectors_source_acl_write" {
    kafka_cluster {
        id = confluent_kafka_cluster.basic.id
    }
    resource_type = "TOPIC"
    resource_name = "postgres"
    pattern_type = "PREFIXED"
    principal = "User:${confluent_service_account.connectors.id}"
    operation = "WRITE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys.id
        secret = confluent_api_key.app_manager_keys.secret
    }
}
# ------------------------------------------------------
# API KEYS
# ------------------------------------------------------
resource "confluent_api_key" "app_manager_keys" {
    display_name = "app-manager-api-key-${random_id.env_display_id.hex}"
    description = "${local.confluent_description}"
    owner {
        id = confluent_service_account.app_manager.id 
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic.id 
        api_version = confluent_kafka_cluster.basic.api_version
        kind = confluent_kafka_cluster.basic.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_env_admin
    ]
}
resource "confluent_api_key" "ksql_keys" {
    display_name = "ksql-api-key-${random_id.env_display_id.hex}"
    description = "${local.confluent_description}"
    owner {
        id = confluent_service_account.ksql.id 
        api_version = confluent_service_account.ksql.api_version
        kind = confluent_service_account.ksql.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic.id 
        api_version = confluent_kafka_cluster.basic.api_version
        kind = confluent_kafka_cluster.basic.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.ksql_cluster_admin,
        confluent_role_binding.ksql_sr_resource_owner
    ]
}
resource "confluent_api_key" "connector_keys" {
    display_name = "connectors-api-key-${random_id.env_display_id.hex}"
    description = "${local.confluent_description}"
    owner {
        id = confluent_service_account.connectors.id 
        api_version = confluent_service_account.connectors.api_version
        kind = confluent_service_account.connectors.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic.id 
        api_version = confluent_kafka_cluster.basic.api_version
        kind = confluent_kafka_cluster.basic.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_create_topic,
        confluent_kafka_acl.connectors_source_acl_write
    ]
}
# ------------------------------------------------------
# KSQL
# ------------------------------------------------------
resource "confluent_ksql_cluster" "ksql_cluster" {
    display_name = "ksql-cluster-${random_id.env_display_id.hex}"
    csu = 1
    environment {
        id = confluent_environment.env.id
    }
    kafka_cluster {
        id = confluent_kafka_cluster.basic.id
    }
    credential_identity {
        id = confluent_service_account.ksql.id
    }
    depends_on = [
        confluent_role_binding.ksql_cluster_admin,
        confluent_role_binding.ksql_sr_resource_owner,
        confluent_api_key.ksql_keys,
        confluent_schema_registry_cluster.sr
    ]
}
# ------------------------------------------------------
# CONNECT
# ------------------------------------------------------
resource "confluent_connector" "postgres_cdc_atm" {
    environment {
        id = confluent_environment.env.id 
    }
    kafka_cluster {
        id = confluent_kafka_cluster.basic.id
    }
    status = "RUNNING"
    config_sensitive = {
        "database.user": "postgres",
        "database.password": "rt-dwh-c0nflu3nt!",
    }
    config_nonsensitive = {
        "connector.class" = "PostgresCdcSource"
        "name": "ATM_DB"
        "database.hostname": "${aws_eip.postgres_atm_eip[0].public_ip}"
        "database.port": "5432"
        "database.dbname": "postgres"
        "database.server.name": "postgres"
        "database.sslmode": "disable"
        "table.include.list": "atm_locations.atm_locations, atm_locations.customers, atm_locations.atm_usage"
        "slot.name": "toad"
        "output.data.format": "JSON_SR"
        "tasks.max": "1"
        "kafka.auth.mode": "SERVICE_ACCOUNT"
        "time.precision.mode":"connect"
        "kafka.service.account.id" = "${confluent_service_account.connectors.id}"
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_create_topic,
        confluent_kafka_acl.connectors_source_acl_write,
        confluent_api_key.connector_keys,
        aws_instance.postgres_atm,
        aws_eip.postgres_atm_eip
    ]
}


# {
#   "name": "PostgresSourceConnector_0",
#   "config": {
#     "connector.class": "PostgresSource",
#     "name": "PostgresSourceConnector_0",
#     "kafka.auth.mode": "SERVICE_ACCOUNT",
#     "kafka.service.account.id": "sa-r0xx37",
#     "topic.prefix": "atm-data",
#     "connection.host": "18.221.241.182",
#     "connection.port": "5432",
#     "connection.user": "postgres",
#     "connection.password": "*****************",
#     "db.name": "postgres",
#     "table.whitelist": "atm_locations.atm_locations, atm_locations.customers, atm_locations.atm_usage",
#     "table.types": "TABLE",
#     "db.timezone": "US/Eastern",
#     "output.data.format": "JSON_SR",
#     "tasks.max": "1"
#   }
# }

# {
#   "name": "RedshiftSinkConnector_0",
#   "config": {
#     "connector.class": "RedshiftSink",
#     "name": "RedshiftSinkConnector_0",
#     "input.data.format": "JSON_SR",
#     "kafka.auth.mode": "SERVICE_ACCOUNT",
#     "kafka.service.account.id": "sa-r0xx37",
#     "topics": "atm-data-atm_locations,atm-data-atm_usage,atm-data-customers",
#     "aws.redshift.domain": "folino-redshift.ca4edirpebk8.us-east-2.redshift.amazonaws.com",
#     "aws.redshift.port": "5439",
#     "aws.redshift.user": "awsuser",
#     "aws.redshift.password": "*********",
#     "aws.redshift.database": "dev",
#     "table.name.format": "kafka_${topic}",
#     "batch.size": "2",
#     "auto.create": "true",
#     "auto.evolve": "true",
#     "tasks.max": "1"
#   }
# }

# {
#   "name": "RedshiftSinkConnector_1",
#   "config": {
#     "connector.class": "RedshiftSink",
#     "name": "RedshiftSinkConnector_1",
#     "input.data.format": "JSON_SR",
#     "kafka.auth.mode": "SERVICE_ACCOUNT",
#     "kafka.service.account.id": "sa-r0xx37",
#     "topics": "postgres.atm_locations.atm_usage,postgres.atm_locations.customers,postgres.atm_locations.atm_locations",
#     "aws.redshift.domain": "folino-redshift.ca4edirpebk8.us-east-2.redshift.amazonaws.com",
#     "aws.redshift.port": "5439",
#     "aws.redshift.user": "awsuser",
#     "aws.redshift.password": "*********",
#     "aws.redshift.database": "dev",
#     "table.name.format": "kafka_${topic}",
#     "batch.size": "2",
#     "auto.create": "true",
#     "auto.evolve": "true",
#     "tasks.max": "1"
#   }
# }
