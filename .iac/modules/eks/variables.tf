variable "client_name" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "node_instance_types" { type = list(string) }
variable "node_desired_size" { type = number }
variable "node_min_size" { type = number }
variable "node_max_size" { type = number }
variable "tooling_node_desired_size" { type = number }
variable "tooling_node_min_size" { type = number }
variable "tooling_node_max_size" { type = number }
variable "app_node_desired_size" { type = number }
variable "app_node_min_size" { type = number }
variable "app_node_max_size" { type = number }
variable "cicd_role_arn" { type = string }
variable "admin_principal_arns" {
  type    = list(string)
  default = []
}
