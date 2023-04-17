variable "name" {
  type    = string
  default = "growthbook"
}

variable "tags" {
  description = "The tags to append to this resource"
  default     = {}
  type        = map(string)
}

# growthbook
variable "environment" {
  description = "Name of the environment"
}

variable "ssm_parameter_prefix" {
  description = "SSM parameter store prefix"
  type        = string
  default     = "/growthbook/"
}

variable "image_name" {
  description = "Docker image to run growthbook with"
  type        = string
  default     = "growthbook/growthbook"
}

variable "image_tag" {
  description = "Verion of growthbook to run. If not specified latest will be used"
  type        = string
  default     = "latest"
}

variable "app_port" {
  description = "Local port growthbook app should be running on"
  type        = number
  default     = 3000
}

variable "api_port" {
  description = "Local port growthbook api should be running on"
  type        = number
  default     = 3100
}

# Container Definition
variable "ecs_task_cpu" {
  description = "The number of cpu units used by the task"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "The amount (in MiB) of memory used by the task"
  type        = number
  default     = 512
}

variable "container_memory_reservation" {
  description = "The amount of memory (in MiB) to reserve for the container"
  type        = number
  default     = 128
}

variable "environment_secrets" {
  description = "List of additional secrets the container will use (list should contain maps with `name` and `valueFrom`)"
  type        = list(map(string))
  default     = []
}

variable "environment_variables" {
  description = "List of additional environment variables the container will use (list should contain maps with `name` and `value`)"
  type        = list(map(string))
  default     = []
}

variable "requires_compatibilities" {
  description = "A set of launch types required by the task. The valid values are EC2 and FARGATE."
  type        = list(string)
  default     = ["FARGATE"]
}

variable "network_mode" {
  description = "The Docker networking mode to use for the containers in the task. The valid values are none, bridge, awsvpc, and host."
  type        = string
  default     = "awsvpc"
}


# ECS Service / Task
variable "ecs_cluster_id" {
  description = "ARN of an ECS cluster"
  type        = string
}

variable "launch_type" {
  description = "The launch type on which to run your service. The valid values are EC2 and FARGATE."
  type        = string
  default     = "FARGATE"
}

variable "ecs_assign_public_ip" {
  description = "Should be true, if ECS service is using public subnets (more info: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_cannot_pull_image.html)"
  type        = bool
  default     = false
}

variable "ecs_subnets" {
  description = "A list of IDs of existing subnets inside the VPC"
  type        = list(string)
}

variable "infrastructure_vpc_cidr" {
  description = "The CIDR of the VPC to allow internal traffic"
  type        = string
}

variable "desired_tasks_count" {
  description = "The number of instances of the task definition to place and keep running"
  type        = number
  default     = 1
}

variable "ecs_service_deployment_maximum_percent" {
  description = "The upper limit (as a percentage of the service's desiredCount) of the number of running tasks that can be running in a service during a deployment"
  type        = number
  default     = 200
}

variable "ecs_service_deployment_minimum_healthy_percent" {
  description = "The lower limit (as a percentage of the service's desiredCount) of the number of running tasks that must remain running and healthy in a service during a deployment"
  type        = number
  default     = 50
}

variable "security_group_ids" {
  description = "List of one or more security groups to be added to the load balancer"
  type        = list(string)
  default     = []
}


# ALB
variable "alb_internal" {
  description = "Boolean determining if the load balancer is internal or externally facing."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "The identifier of the VPC in which to create resources"
  type        = string
}

variable "alb_subnets" {
  description = "A list of IDs of existing subnets inside the VPC"
  type        = list(string)
}

variable "alb_ssl_cert_arn" {
  description = "The ARN of the default SSL server certificate. Exactly one certificate is required if the protocol is HTTPS."
  type        = string
}

# Database
variable "db_username" {
  type        = string
  description = "(Required unless a snapshot_identifier is provided) Username for the master DB user"
}

variable "db_password" {
  type        = string
  description = "(Required unless a snapshot_identifier is provided) Password for the master DB user. Note that this may show up in logs, and it will be stored in the state file. Please refer to the DocumentDB Naming Constraints"
}

variable "instance_class" {
  type        = string
  default     = "db.t4g.medium"
  description = "The instance class to use. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-classes.html#db-instance-class-specs"
}

variable "db_port" {
  type        = number
  default     = 27017
  description = "DocumentDB port"
}

variable "engine" {
  type        = string
  default     = "docdb"
  description = "The name of the database engine to be used for this DB cluster. Defaults to `docdb`. Valid values: `docdb`"
}

variable "engine_version" {
  type        = string
  default     = "4.0.0"
  description = "The version number of the database engine to use"
}

variable "cluster_family" {
  type        = string
  default     = "docdb4.0"
  description = "The family of the DocumentDB cluster parameter group. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-cluster-parameter-group-create.html"
}

variable "cluster_size" {
  type        = number
  default     = 1
  description = "Number of DB instances to create in the cluster"
}

variable "retention_period" {
  type        = number
  default     = 7
  description = "Number of days to retain backups for"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Determines whether a final DB snapshot is created before the DB cluster is deleted"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "A value that indicates whether the DB cluster has deletion protection enabled"
  default     = false
}

variable "apply_immediately" {
  type        = bool
  description = "Specifies whether any cluster modifications are applied immediately, or during the next maintenance window"
  default     = true
}

variable "storage_encrypted" {
  type        = bool
  description = "Specifies whether the DB cluster is encrypted"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "The ARN for the KMS encryption key. When specifying `kms_key_id`, `storage_encrypted` needs to be set to `true`"
  default     = ""
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Specifies whether any minor engine upgrades will be applied automatically to the DB instance during the maintenance window or not"
  default     = true
}

variable "cluster_parameters" {
  type = list(object({
    apply_method = string
    name         = string
    value        = string
  }))
  default     = []
  description = "List of DB parameters to apply"
}


# S3
variable "s3_bucket_name" {
  type        = string
  description = "Name of the S3 bucket to store uploaded files and screenshots"
}

variable "s3_region" {
  type        = string
  description = "Region of the S3 bucket"
  default     = "us-east-1"
}


# Notifications
variable "enable_notifications" {
  type        = bool
  description = "Specifies whether to enable slack notification on changes made to feature definitions"
  default     = false
}

variable "slack_token" {
  type        = string
  description = "Access tokens are the keys of the Slack platform"
  default     = ""
}

variable "slack_channel" {
  type        = string
  description = "Name of the slack channel where notifications will be sent"
  default     = ""
}


# Cloudwatch
variable "cloudwatch_log_retention_in_days" {
  description = "Retention period of growthbook CloudWatch logs"
  type        = number
  default     = 7
}
