# terraform-aws-growthbook-ecs

A Terraform module which deploys Growthbook platform on AWS ECS.

## Usage

GrowthBook is an open-source platform for feature flagging and a/b testing built for data teams, engineers, and product managers. It's great whether you're looking to just analyze experiment results or looking to make it easier to deploy code.

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "2.57.0"

  name                 = "production"
  cidr                 = "10.10.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  private_subnets      = ["10.10.0.0/20", "10.10.16.0/20"]
  public_subnets       = ["10.10.128.0/20", "10.10.144.0/20"]
  enable_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    owner       = "terraform"
    environment = "production"
    team        = "infra"
  }
}

module "growthbook-ecs-cluster" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "growthbook-ecs-fargate"

  tags = {
    owner       = "terraform"
    environment = "production"
    project     = "growthbook"
    team        = "infra"
  }
}

module "growthbook-ecs" {
  source = ""g2crowd/terraform-aws-growthbook-ecs/aws"

  environment             = "production"
  image_tag               = "latest"
  ecs_cluster_id          = module.growthbook-ecs-cluster.ecs_cluster_id
  vpc_id                  = module.vpc.vpc_id
  infrastructure_vpc_cidr = module.vpc.vpc_cidr_block
  ecs_subnets             = module.vpc.private_subnets
  alb_subnets             = module.vpc.public_subnets
  alb_ssl_cert_arn        = data.terraform_remote_state.global.outputs.acm_production_g2
  db_username             = var.db_username
  db_password             = var.db_password
  s3_bucket_name          = var.s3_bucket_name

  environment_variables = [
    {
      name  = "APP_ORIGIN"
      value = "https://growthbook.${var.domain_name}"
    },
    {
      name  = "CORS_ORIGIN_REGEX"
      value = "https://growthbook.${var.domain_name}*"
    },
    {
      name  = "API_HOST"
      value = "https://growthbook.${var.domain_name}:3100"
    },
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "JWT_SECRET"
      value = var.jwt_secret
    },
    {
      name  = "ENCRYPTION_KEY"
      value = var.encryption_key
    }
  ]

  tags = {
    project     = "growthbook"
    team        = "infra"
    owner       = "terraform"
    environment = "production"
  }
}

resource "aws_route53_record" "growthbook" {
  provider = aws.dns

  zone_id = var.hosted_zone_id
  name    = "growthbook.${var.domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [module.growthbook-ecs.alb_domain_name]
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.25.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.25.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module\_container\_definition"></a> [#module\_container\_definition](#module\_container\_definition) | cloudposse/ecs-container-definition/aws | 0.58.1 |
| <a name="module\_alb"></a> [module\_alb](#module\_alb) | terraform-aws-modules/alb/aws | 5.13 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_docdb_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster) | resource |
| [aws_docdb_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster_instance) | resource |
| [aws_docdb_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_subnet_group) | resource |
| [aws_docdb_cluster_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster_parameter_group) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_lambda_permission.lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.frontend_http_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.frontend_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_certificate.https_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_rule.http_tcp_listener_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.https_listener_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_listener_rule.redirect_http_to_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_external_http_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_external_https_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_external_api_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_internal_http_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_internal_https_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_internal_api_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_all_out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.ecs_alb_app_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_alb_api_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_all_out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.ecs_db_app_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.db_all_out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="name"></a> [name](#name) | The name of the service | `string` | `growthbook` | no |
| <a name="tags"></a> [tags](#tags) | The tags to append to this resource | `map(string)` | `{}` | no |
| <a name="environment"></a> [environment](#environment) | The name of the environment | `string` | `""` | yes |
| <a name="image_name"></a> [image\_name](#image\_name) | Docker image to run growthbook with | `string` | `growthbook/growthbook` | no |
| <a name="image_tag"></a> [image\_tag](#image\_tag) | Verion of growthbook to run. If not specified latest will be used | `string` | `latest` | no |
| <a name="app_port"></a> [app\_port](#app\_port) | Local port growthbook app should be running on | `number` | `3000` | no |
| <a name="api_port"></a> [api\_port](#api\_port) | Local port growthbook api should be running on | `number` | `3100` | no |
| <a name="ecs_task_cpu"></a> [ecs\_task\_cpu](#ecs\_task\_cpu) | The number of cpu units used by the task | `number` | `256` | no |
| <a name="ecs_task_memory"></a> [ecs\_task\_memory](#ecs\_task\_memory) | The amount (in MiB) of memory used by the task | `number` | `512` | no |
| <a name="container_memory_reservation"></a> [container\_memory\_reservation](#container\_memory\_reservation) | The amount of memory (in MiB) to reserve for the container | `number` | `128` | no |
| <a name="environment_secrets"></a> [environment\_secrets](#environment\_secrets) | List of additional secrets the container will use (list should contain maps with `name` and `valueFrom`) | `list(map(string))` | `[]` | no |
| <a name="environment_variables"></a> [environment\_variables](#environment\_variables) | List of additional environment variables the container will use (list should contain maps with `name` and `value`) | `list(map(string))` | `[]` | no |
| <a name="requires_compatibilities"></a> [requires\_compatibilities](#requires\_compatibilities) | A set of launch types required by the task. The valid values are EC2 and FARGATE. | `list(string)` | `["FARGATE"]` | no |
| <a name="network_mode"></a> [network\_mode](#network\_mode) | The Docker networking mode to use for the containers in the task. The valid values are none, bridge, awsvpc, and host. | `string` | `awsvpc` | no |
| <a name="ecs_cluster_id"></a> [ecs\_cluster\_id](#ecs\_cluster\_id) | The ARN of an ECS cluster | `string` | `""` | yes |
| <a name="launch_type"></a> [launch\_type](#launch\_type) | The launch type on which to run your service. The valid values are EC2 and FARGATE. | `string` | `FARGATE` | no |
| <a name="ecs_assign_public_ip"></a> [ecs\_assign\_public\_ip](#ecs\_assign\_public\_ip) | Should be true, if ECS service is using public subnets (more info: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_cannot_pull_image.html) | `bool` | `false` | no |
| <a name="ecs_subnets"></a> [ecs\_subnets](#ecs\_subnets) | A list of IDs of existing subnets inside the VPC | `list(string)` | `[]` | yes |
| <a name="infrastructure_vpc_cidr"></a> [infrastructure\_vpc\_cidr](#infrastructure\_vpc\_cidr) | The CIDR of the VPC to allow internal traffic | `string` | `""` | yes |
| <a name="desired_tasks_count"></a> [desired\_tasks\_count](#desired\_tasks\_count) | The number of instances of the task definition to place and keep running | `number` | `1` | no |
| <a name="ecs_service_deployment_maximum_percent"></a> [ecs\_service\_deployment\_maximum\_percent](#ecs\_service\_deployment\_maximum\_percent) | The upper limit (as a percentage of the service's desiredCount) of the number of running tasks that can be running in a service during a deployment | `number` | `200` | no |
| <a name="ecs_service_deployment_minimum_healthy_percent"></a> [ecs\_service\_deployment\_minimum\_healthy\_percent](#ecs\_service\_deployment\_minimum\_healthy\_percent) | The lower limit (as a percentage of the service's desiredCount) of the number of running tasks that must remain running and healthy in a service during a deployment | `number` | `50` | no |
| <a name="security_group_ids"></a> [security\_group\_ids](#security\_group\_ids) | List of one or more security groups to be added to the load balancer | `list(string)` | `[]` | no |
| <a name="alb_internal"></a> [alb\_internal](#alb\_internal) | Boolean determining if the load balancer is internal or externally facing. | `bool` | `false` | no |
| <a name="vpc_id"></a> [vpc\_id](#vpc\_id) | The identifier of the VPC in which to create resources | `string` | `""` | yes |
| <a name="alb_subnets"></a> [alb\_subnets](#alb\_subnets) | A list of IDs of existing subnets inside the VPC | `list(string)` | `[]` | yes |
| <a name="alb_ssl_cert_arn"></a> [alb\_ssl\_cert\_arn](#alb\_ssl\_cert\_arn) | The ARN of the default SSL server certificate. Exactly one certificate is required if the protocol is HTTPS. | `string` | `""` | yes |
| <a name="db_username"></a> [db\_username](#db\_username) | (Required unless a snapshot_identifier is provided) Username for the master DB user | `string` | `""` | yes |
| <a name="db_password"></a> [db\_password](#db\_password) | (Required unless a snapshot_identifier is provided) Password for the master DB user. Note that this may show up in logs, and it will be stored in the state file. Please refer to the DocumentDB Naming Constraints | `string` | `""` | yes |
| <a name="instance_class"></a> [instance\_class](#instance\_class) | The instance class to use. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-classes.html#db-instance-class-specs | `string` | `db.t4g.medium` | no |
| <a name="db_port"></a> [db\_port](#db\_port) | DocumentDB port | `number` | `27017` | no |
| <a name="engine"></a> [engine](#engine) | The name of the database engine to be used for this DB cluster. Defaults to `docdb`. Valid values: `docdb` | `string` | `docdb` | no |
| <a name="engine_version"></a> [engine\_version](#engine\_version) | The version number of the database engine to use | `string` | `4.0.0` | no |
| <a name="cluster_family"></a> [cluster\_family](#cluster\_family) | The family of the DocumentDB cluster parameter group. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-cluster-parameter-group-create.html | `string` | `docdb4.0` | no |
| <a name="retention_period"></a> [retention\_period](#retention\_period) | Number of days to retain backups for | `number` | `7` | no |
| <a name="skip_final_snapshot"></a> [skip\_final\_snapshot](#skip\_final\_snapshot) | Determines whether a final DB snapshot is created before the DB cluster is deleted | `bool` | `true` | no |
| <a name="deletion_protection"></a> [deletion\_protection](#deletion\_protection) | A value that indicates whether the DB cluster has deletion protection enabled | `bool` | `false` | no |
| <a name="apply_immediately"></a> [apply\_immediately](#apply\_immediately) | Specifies whether any cluster modifications are applied immediately, or during the next maintenance window | `bool` | `true` | no |
| <a name="storage_encrypted"></a> [storage\_encrypted](#storage\_encrypted) | Specifies whether the DB cluster is encrypted | `bool` | `true` | no |
| <a name="kms_key_id"></a> [kms\_key\_id](#kms\_key\_id) | The ARN for the KMS encryption key. When specifying `kms_key_id`, `storage_encrypted` needs to be set to `true` | `string` | `""` | no |
| <a name="auto_minor_version_upgrade"></a> [auto\_minor\_version\_upgrade](#auto\_minor\_version\_upgrade) | Specifies whether any minor engine upgrades will be applied automatically to the DB instance during the maintenance window or not | `bool` | `true` | no |
| <a name="cluster_parameters"></a> [cluster\_parameters](#cluster\_parameters) | List of DB parameters to apply | `list(object({}))` | `""` | no |
| <a name="s3_bucket_name"></a> [s3\_bucket\_name](#s3\_bucket\_name) | Name of the S3 bucket to store uploaded files and screenshots | `string` | `""` | yes |
| <a name="s3_region"></a> [s3\_region](#s3\_region) | Region of the S3 bucket | `string` | `us-east-1` | no |
| <a name="cloudwatch_log_retention_in_days"></a> [cloudwatch\_log\_retention\_in\_days](#cloudwatch\_log\_retention\_in\_days) | Retention period of growthbook CloudWatch logs | `number` | `7` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="alb_domain_name"></a> [alb\_domain\_name](#alb\_domain\_named) | The DNS name of the load balancer |

# License

Apache 2 Licensed. See [LICENSE](https://github.com/g2crowd/terraform-aws-growthbook-ecs/tree/master/LICENSE) for full details.
