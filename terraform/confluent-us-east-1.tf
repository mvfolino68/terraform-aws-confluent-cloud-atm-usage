resource "random_id" "env_display_id_useast1" {
    byte_length = 4
}
# ------------------------------------------------------
# KAFKA
# ------------------------------------------------------
resource "confluent_kafka_cluster" "basic_useast1" {
    display_name = "gko-case-cluster_useast1${random_id.env_display_id_useast1.hex}"
    availability = "MULTI_ZONE"
    cloud = "AWS"
    region = "${local.aws_region_useast1}"
    standard {}
    environment {
        id = confluent_environment.env.id
    }
}
# ------------------------------------------------------
# SERVICE ACCOUNTS
# ------------------------------------------------------
resource "confluent_service_account" "app_manager_useast1" {
    display_name = "app-manager-sa-${random_id.env_display_id_useast1.hex}"
    description = "${local.confluent_description}"
}
resource "confluent_service_account" "ksql_useast1" {
    display_name = "ksql-${random_id.env_display_id_useast1.hex}"
    description = "${local.confluent_description}"
}
resource "confluent_service_account" "connectors_useast1" {
    display_name = "connector-sa-${random_id.env_display_id_useast1.hex}"
    description = "${local.confluent_description}"
}
# ------------------------------------------------------
# ROLE BINDINGS
# ------------------------------------------------------
resource "confluent_role_binding" "app_manager_env_admin_useast1" {
    principal = "User:${confluent_service_account.app_manager_useast1.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.env.resource_name
}
resource "confluent_role_binding" "ksql_cluster_admin_useast1" {
    principal = "User:${confluent_service_account.ksql_useast1.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.basic_useast1.rbac_crn
}
resource "confluent_role_binding" "ksql_sr_resource_owner_useast1" {
    principal = "User:${confluent_service_account.ksql_useast1.id}"
    role_name = "ResourceOwner"
    crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sr_useast1.resource_name, "subject=*")
}
# ------------------------------------------------------
# ACLS
# ------------------------------------------------------
resource "confluent_kafka_acl" "connectors_source_acl_describe_cluster_useast1" {
    kafka_cluster {
        id = confluent_kafka_cluster.basic_useast1.id
    }
    resource_type = "CLUSTER"
    resource_name = "kafka-cluster"
    pattern_type = "LITERAL"
    principal = "User:${confluent_service_account.connectors_useast1.id}"
    operation = "DESCRIBE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.basic_useast1.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys_useast1.id
        secret = confluent_api_key.app_manager_keys_useast1.secret
    }
}
resource "confluent_kafka_acl" "connectors_source_acl_create_topic_useast1" {
    kafka_cluster {
        id = confluent_kafka_cluster.basic_useast1.id
    }
    resource_type = "TOPIC"
    resource_name = "postgres"
    pattern_type = "PREFIXED"
    principal = "User:${confluent_service_account.connectors_useast1.id}"
    operation = "CREATE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.basic_useast1.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys_useast1.id
        secret = confluent_api_key.app_manager_keys_useast1.secret
    }
}
resource "confluent_kafka_acl" "connectors_source_acl_write_useast1" {
    kafka_cluster {
        id = confluent_kafka_cluster.basic_useast1.id
    }
    resource_type = "TOPIC"
    resource_name = "postgres"
    pattern_type = "PREFIXED"
    principal = "User:${confluent_service_account.connectors_useast1.id}"
    operation = "WRITE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.basic_useast1.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys_useast1.id
        secret = confluent_api_key.app_manager_keys_useast1.secret
    }
}
# ------------------------------------------------------
# API KEYS
# ------------------------------------------------------
resource "confluent_api_key" "app_manager_keys_useast1" {
    display_name = "app-manager-api-key-${random_id.env_display_id_useast1.hex}"
    description = "${local.confluent_description}"
    owner {
        id = confluent_service_account.app_manager_useast1.id 
        api_version = confluent_service_account.app_manager_useast1.api_version
        kind = confluent_service_account.app_manager_useast1.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic_useast1.id 
        api_version = confluent_kafka_cluster.basic_useast1.api_version
        kind = confluent_kafka_cluster.basic_useast1.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_env_admin_useast1
    ]
}
resource "confluent_api_key" "ksql_keys_useast1" {
    display_name = "ksql-api-key-${random_id.env_display_id_useast1.hex}"
    description = "${local.confluent_description}"
    owner {
        id = confluent_service_account.ksql_useast1.id 
        api_version = confluent_service_account.ksql_useast1.api_version
        kind = confluent_service_account.ksql_useast1.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic_useast1.id 
        api_version = confluent_kafka_cluster.basic_useast1.api_version
        kind = confluent_kafka_cluster.basic_useast1.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.ksql_cluster_admin_useast1,
        confluent_role_binding.ksql_sr_resource_owner_useast1
    ]
}
resource "confluent_api_key" "connector_keys_useast1" {
    display_name = "connectors-api-key-${random_id.env_display_id_useast1.hex}"
    description = "${local.confluent_description}"
    owner {
        id = confluent_service_account.connectors_useast1.id 
        api_version = confluent_service_account.connectors_useast1.api_version
        kind = confluent_service_account.connectors_useast1.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic_useast1.id 
        api_version = confluent_kafka_cluster.basic_useast1.api_version
        kind = confluent_kafka_cluster.basic_useast1.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_create_topic_useast1,
        confluent_kafka_acl.connectors_source_acl_write_useast1
    ]
}
# ------------------------------------------------------
# KSQL
# ------------------------------------------------------
resource "confluent_ksql_cluster" "ksql_cluster_useast1" {
    display_name = "ksql-cluster-${random_id.env_display_id_useast1.hex}"
    csu = 1
    environment {
        id = confluent_environment.env.id
    }
    kafka_cluster {
        id = confluent_kafka_cluster.basic_useast1.id
    }
    credential_identity {
        id = confluent_service_account.ksql_useast1.id
    }
    depends_on = [
        confluent_role_binding.ksql_cluster_admin_useast1,
        confluent_role_binding.ksql_sr_resource_owner_useast1,
        confluent_api_key.ksql_keys_useast1,
        confluent_schema_registry_cluster.sr_useast1
    ]
}
# ------------------------------------------------------
# CONNECT
# ------------------------------------------------------
resource "confluent_connector" "postgres_cdc_products_useast1" {
    environment {
        id = confluent_environment.env.id 
    }
    kafka_cluster {
        id = confluent_kafka_cluster.basic_useast1.id
    }
    status = "RUNNING"
    config_sensitive = {
        "database.user": "postgres",
        "database.password": "rt-dwh-c0nflu3nt!",
    }
    config_nonsensitive = {
        "connector.class" = "PostgresCdcSource"
        "name": "PRODUCTS_DB-useast1"
        "topic.prefix": "us-east-1" # I don't think this has any effect, but is possible according to debezium docs
        "database.hostname": "${aws_eip.postgres_products_eip_useast1[0].public_ip}"
        "database.port": "5432"
        "database.dbname": "postgres"
        "database.server.name": "postgres"
        "database.sslmode": "disable"
        "table.include.list": "products.products, products.orders"
        "slot.name": "toad"
        "output.data.format": "JSON_SR"
        "tasks.max": "1"
        "kafka.auth.mode": "SERVICE_ACCOUNT"
        "kafka.service.account.id" = "${confluent_service_account.connectors_useast1.id}"
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_create_topic_useast1,
        confluent_kafka_acl.connectors_source_acl_write_useast1,
        confluent_api_key.connector_keys_useast1,
        aws_instance.postgres_products_useast1,
        aws_eip.postgres_products_eip_useast1
    ]
}
