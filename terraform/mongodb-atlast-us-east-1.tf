# resource "random_id" "env_display_id_tg" {
#     byte_length = 4
# }
# ------------------------------------------------------
# MONGODB ATLAS PROJECT
# ------------------------------------------------------
# data "mongodbatlas_project" "my_project" {
#   name = "my-project"
# }

# ------------------------------------------------------
# MONGODB ATLAS CLUSTER
# ------------------------------------------------------
# resource "mongodbatlas_cluster" "my_cluster" {
#   name         = "my-cluster-${random_id.env_display_id.hex}"
#   provider_name = "AWS"
#   instance_size_name = "M0"
#   num_shards = 1
#   replication_factor = 3
# }
# ------------------------------------------------------
# DATABASE AND COLLECTION
# ------------------------------------------------------
# resource "mongodbatlas_database" "dev" {
#   name = "atm_database"
#   project_id = "${data.mongodbatlas_project.my_project.id}"
#   shard_name = "${mongodbatlas_cluster.my_cluster.shard_names[0]}"
# }

# resource "mongodbatlas_collection" "atm_collection" {
#   name         = "atm_collection"
#   database_name = "${mongodbatlas_database.atm_database.name}"
#   project_id = "${data.mongodbatlas_project.my_project.id}"
# }
