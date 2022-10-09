### Lambda
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "= 2.36.0"

  create_function = var.enable_notifications
  function_name   = "${var.environment}_${var.name}"
  description     = "Growthbook notification lambda function"
  handler         = "main.lambda_handler"
  runtime         = "python3.7"
  source_path     = "${path.module}/src"
  tags            = var.tags

  attach_policy_statements = true
  policy_statements        = {
    dynamodb = {
      effect    = "Allow",
      actions   = ["dynamodb:BatchGetItem", "dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchWriteItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"],
      resources = ["${aws_dynamodb_table.this[0].arn}"]
    }
  }

  environment_variables = {
    SLACK_TOKEN   = var.slack_token
    SLACK_CHANNEL = var.slack_channel
    DB_TABLE_NAME = "${var.environment}-${var.name}"
  }
}


### Dynamo DB
resource "aws_dynamodb_table" "this" {
  count =  var.enable_notifications ? 1 : 0

  name           = "${var.environment}-${var.name}"
  hash_key       = "Data"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  tags           = var.tags

  attribute {
    name = "Data"
    type = "S"
  }
}

### Load balancer
resource "aws_lb" "this" {
  count =  var.enable_notifications ? 1 : 0

  name                       = "${var.environment}-${var.name}-notify"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.notification_alb[0].id]
  subnets                    = var.ecs_subnets
  enable_deletion_protection = false
  tags                       = var.tags
}

resource "aws_lb_target_group" "notification" {
  count =  var.enable_notifications ? 1 : 0

  name        = "${var.environment}-${var.name}-notify"
  target_type = "lambda"
}

resource "aws_lambda_permission" "this" {
  count =  var.enable_notifications ? 1 : 0

  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.notification[0].arn
}

resource "aws_lb_target_group_attachment" "notification" {
  count =  var.enable_notifications ? 1 : 0

  target_group_arn = aws_lb_target_group.notification[0].arn
  target_id        = module.lambda_function.lambda_function_arn
  depends_on       = [aws_lambda_permission.this]
}

resource "aws_lb_listener" "notification" {
  count =  var.enable_notifications ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.alb_ssl_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.notification[0].arn
  }
}


### Security groups
resource "aws_security_group" "notification_alb" {
  count =  var.enable_notifications ? 1 : 0

  name        = "${var.environment}_${var.name}_notify"
  description = "${var.name}_${var.environment} ALB security group"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "notification_alb_internal_https_in" {
  count =  var.enable_notifications ? 1 : 0

  security_group_id        = aws_security_group.notification_alb[0].id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "notification_alb_all_out" {
  count =  var.enable_notifications ? 1 : 0

  security_group_id = aws_security_group.notification_alb[0].id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
