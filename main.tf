### Variable
locals {
  env_variables = [
    {
      name  = "S3_BUCKET"
      value = var.s3_bucket_name
    },
    {
      name  = "S3_REGION"
      value = var.s3_region
    },
    {
      name  = "MONGODB_URI"
      value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster.this.endpoint}:${var.db_port}/?retryWrites=false&directConnection=true&tls=true&tlsCAFile=/usr/local/src/app/rds-combined-ca-bundle.pem"
    }
  ]
}


### Cloudwatch logs
resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags              = var.tags
}


### S3 bucket
resource "aws_s3_bucket" "this" {
  bucket = var.s3_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


### Iam
resource "aws_iam_role" "this" {
  name = "${var.environment}_${var.name}_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_policy" "this" {
  name = "${var.environment}_${var.name}_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${var.s3_bucket_name}/*",
        "arn:aws:s3:::${var.s3_bucket_name}"
      ]
    },
    {
      "Action": [
        "logs:Create*",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}


### Database
resource "aws_docdb_cluster" "this" {
  cluster_identifier              = "${var.environment}-${var.name}"
  master_username                 = var.db_username
  master_password                 = var.db_password
  engine                          = var.engine
  engine_version                  = var.engine_version
  port                            = var.db_port
  backup_retention_period         = var.retention_period
  skip_final_snapshot             = var.skip_final_snapshot
  deletion_protection             = var.deletion_protection
  apply_immediately               = var.apply_immediately
  storage_encrypted               = var.storage_encrypted
  kms_key_id                      = var.kms_key_id
  vpc_security_group_ids          = [aws_security_group.db.id]
  db_subnet_group_name            = aws_docdb_subnet_group.this.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name
  tags                            = var.tags
}

resource "aws_docdb_cluster_instance" "this" {
  count = var.cluster_size

  identifier                 = "${var.environment}-${var.name}-${count.index + 1}"
  cluster_identifier         = aws_docdb_cluster.this.id
  apply_immediately          = var.apply_immediately
  instance_class             = var.instance_class
  engine                     = var.engine
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  tags                       = var.tags
}

resource "aws_docdb_subnet_group" "this" {
  name        = "${var.environment}-${var.name}"
  description = "Allowed subnets for DB cluster instances"
  subnet_ids  = var.ecs_subnets
  tags        = var.tags
}

# https://docs.aws.amazon.com/documentdb/latest/developerguide/db-cluster-parameter-group-create.html
resource "aws_docdb_cluster_parameter_group" "this" {
  name        = "${var.environment}-${var.name}"
  description = "DB cluster parameter group"
  family      = var.cluster_family
  tags        = var.tags

  dynamic "parameter" {
    for_each = var.cluster_parameters
    content {
      apply_method = lookup(parameter.value, "apply_method", null)
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }
}


### Task defination
module "container_definition" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "~> 0.58.1"

  container_name               = "${var.environment}_${var.name}"
  container_image              = "${var.image_name}:${var.image_tag}"
  command                      = ["bash", "-c", "wget https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem && yarn start"]
  container_memory             = var.ecs_task_memory
  container_memory_reservation = var.container_memory_reservation
  container_cpu                = var.ecs_task_cpu
  secrets                      = var.environment_secrets

  environment = concat(
    local.env_variables,
    var.environment_variables,
  )

  port_mappings = [
    {
      containerPort = var.app_port
      hostPort      = var.app_port
      protocol      = "tcp"
    },
    {
      containerPort = var.api_port
      hostPort      = var.api_port
      protocol      = "tcp"
    },
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = "us-east-1"
      "awslogs-group"         = aws_cloudwatch_log_group.this.name
      "awslogs-stream-prefix" = var.name
    }
    secretOptions = null
  }

  depends_on = [aws_docdb_cluster.this, aws_docdb_cluster_instance.this]
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment}_${var.name}"
  container_definitions    = "[${module.container_definition.json_map_encoded}]"
  requires_compatibilities = var.requires_compatibilities
  network_mode             = var.network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.this.arn
  task_role_arn            = aws_iam_role.this.arn
  tags                     = var.tags
}

resource "aws_ecs_service" "service" {
  name                               = "${var.environment}_${var.name}"
  cluster                            = var.ecs_cluster_id
  task_definition                    = "${aws_ecs_task_definition.this.family}:${aws_ecs_task_definition.this.revision}"
  desired_count                      = var.desired_tasks_count
  launch_type                        = var.launch_type
  deployment_maximum_percent         = var.ecs_service_deployment_maximum_percent
  deployment_minimum_healthy_percent = var.ecs_service_deployment_minimum_healthy_percent

  network_configuration {
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.ecs_subnets
    assign_public_ip = var.ecs_assign_public_ip
  }

  load_balancer {
    target_group_arn = element(module.alb.target_group_arns, 0)
    container_name   = "${var.environment}_${var.name}"
    container_port   = var.app_port
  }

  load_balancer {
    target_group_arn = element(module.alb.target_group_arns, 1)
    container_name   = "${var.environment}_${var.name}"
    container_port   = var.api_port
  }

  depends_on = [module.alb, aws_ecs_task_definition.this, aws_docdb_cluster.this, aws_docdb_cluster_instance.this]
}

### Load balancer
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "= 5.13"

  name                        = "${var.environment}-${var.name}"
  internal                    = var.alb_internal
  vpc_id                      = var.vpc_id
  subnets                     = var.alb_subnets
  security_groups             = flatten([aws_security_group.alb.id])
  listener_ssl_policy_default = "ELBSecurityPolicy-TLS-1-2-2017-01"

  target_groups = [
    {
      name             = "${var.environment}-${var.name}-app"
      backend_protocol = "HTTP"
      backend_port     = var.app_port
      target_type      = "ip"
    },
    {
      name             = "${var.environment}-${var.name}-api"
      backend_protocol = "HTTP"
      backend_port     = var.api_port
      target_type      = "ip"
      health_check = {
        port = var.app_port
      }
    },
  ]

  https_listeners = [
    {
      port               = 443
      certificate_arn    = var.alb_ssl_cert_arn
      target_group_index = 0
    },
    {
      port               = var.api_port
      certificate_arn    = var.alb_ssl_cert_arn
      target_group_index = 1
    },
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  tags = var.tags
}

resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = module.alb.http_tcp_listener_arns[0]

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

### Security groups
# ALB
resource "aws_security_group" "alb" {
  name        = "${var.environment}_${var.name}_alb_sg"
  description = "${var.environment}_${var.name} ALB security group"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "alb_external_http_in" {
  count = var.alb_internal ? 0 : 1

  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_external_https_in" {
  count = var.alb_internal ? 0 : 1

  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_external_api_in" {
  count = var.alb_internal ? 0 : 1

  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = var.api_port
  to_port           = var.api_port
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_internal_http_in" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = [var.infrastructure_vpc_cidr]
}

resource "aws_security_group_rule" "alb_internal_https_in" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = [var.infrastructure_vpc_cidr]
}

resource "aws_security_group_rule" "alb_internal_api_in" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = var.api_port
  to_port           = var.api_port
  cidr_blocks       = [var.infrastructure_vpc_cidr]
}

resource "aws_security_group_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# ECS task
resource "aws_security_group" "ecs" {
  name        = "${var.environment}_${var.name}_ecs_sg"
  description = "${var.environment}_${var.name} ECS security group"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "ecs_alb_app_in" {
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.app_port
  to_port                  = var.app_port
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_alb_api_in" {
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.api_port
  to_port                  = var.api_port
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_all_out" {
  security_group_id = aws_security_group.ecs.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# Database
resource "aws_security_group" "db" {
  name        = "${var.environment}_${var.name}_db_sg"
  description = "${var.environment}_${var.name} DB security group"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "ecs_db_app_in" {
  security_group_id        = aws_security_group.db.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.db_port
  to_port                  = var.db_port
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "db_all_out" {
  security_group_id = aws_security_group.db.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
