# Define some convenience variables to consolidate some conditional logic.
locals {
  ssl = var.server_url_certificate_arn == "" ? false : true
}

# Fetch the current region
data "aws_region" "current" {}

resource "aws_security_group" "appiands" {
  count       = var.create_new_db == true ? 1 : 0
  name        = "appiands-${var.name}"
  description = "Appian system data store security group"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "appiands_ingress" {
  count                    = var.create_new_db == true ? 1 : 0
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.appian.id
  security_group_id        = aws_security_group.appiands[0].id
}

resource "aws_db_parameter_group" "appiands" {
  count  = var.create_new_db == true ? 1 : 0
  family = "mysql5.7"
  name   = "appiands-${var.name}"
  parameter {
    apply_method = "immediate"
    name         = "character_set_client"
    value        = "utf8"
  }
  parameter {
    apply_method = "immediate"
    name         = "character_set_server"
    value        = "utf8"
  }
}

resource "aws_db_subnet_group" "appiands" {
  count       = var.create_new_db == true ? 1 : 0
  description = "Database subnet group for demodb"
  name        = "appiands-${var.name}"
  subnet_ids  = var.db_subnets
}

resource "aws_db_instance" "appiands" {
  count                               = var.create_new_db == true ? 1 : 0
  allocated_storage                   = var.db_allocated_storage
  allow_major_version_upgrade         = false
  apply_immediately                   = false
  auto_minor_version_upgrade          = true
  backup_retention_period             = 0
  backup_window                       = "03:00-06:00"
  db_subnet_group_name                = aws_db_subnet_group.appiands[0].name
  engine                              = "mysql"
  engine_version                      = "5.7.19"
  final_snapshot_identifier           = "appiands-${var.name}"
  iam_database_authentication_enabled = false
  identifier                          = "appiands-${var.name}"
  instance_class                      = var.db_instance_class
  maintenance_window                  = "mon:00:00-mon:03:00"
  multi_az                            = false
  name                                = "appiands"
  parameter_group_name                = aws_db_parameter_group.appiands[0].name
  password                            = var.db_password
  port                                = "3306"
  skip_final_snapshot                 = true
  storage_encrypted                   = true
  username                            = var.db_username
  vpc_security_group_ids              = [aws_security_group.appiands[0].id]
  tags = {
    appian_environment = var.appian_environment
  }
}

# Create an iam role for appian to eventually assume
resource "aws_iam_role" "appian_host" {
  name               = "appian-host-role-${var.name}"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Create the iam instance profile that will be assigned to the appian ec2 instance
resource "aws_iam_instance_profile" "appian_host" {
  name = "appian-host-profile-${var.name}"
  path = "/"
  role = aws_iam_role.appian_host.name
}

resource "aws_security_group" "appian" {
  name        = "appian-ec2-${var.name}"
  description = "Appian Security Group for ${var.name}"
  vpc_id      = var.vpc_id
}

# Allow Appian EC2 to reach out anywhere.
resource "aws_security_group_rule" "appian_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.appian.id
}

resource "aws_security_group" "engines" {
  name   = "appian-engines-${var.name}"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 5000
    to_port         = 5083
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server.id]
    self            = true
  }
  ingress {
    from_port       = 7070
    to_port         = 7070
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server.id]
    self            = true
  }
}
resource "aws_security_group" "data_server" {
  name   = "appian-data_server-${var.name}"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 9300
    to_port         = 9301
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server.id]
    self            = true
  }
}
resource "aws_security_group" "search_server" {
  name   = "appian-search_server-${var.name}"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 5400
    to_port         = 5407
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server.id]
    self            = true
  }
  ingress {
    from_port       = 5450
    to_port         = 5451
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server.id]
    self            = true
  }
}
resource "aws_security_group" "internal_messaging" {
  name   = "appian-internal-messaging-${var.name}"
  vpc_id = var.vpc_id
  ingress {
    from_port = 2181
    to_port   = 2181
    protocol  = "tcp"
    security_groups = [
      aws_security_group.app_server.id,
      aws_security_group.engines.id,
      aws_security_group.data_server.id,
      aws_security_group.search_server.id
    ]
    self = true
  }
  ingress {
    from_port = 2888
    to_port   = 2888
    protocol  = "tcp"
    security_groups = [
      aws_security_group.app_server.id,
      aws_security_group.engines.id,
      aws_security_group.data_server.id,
      aws_security_group.search_server.id
    ]
    self = true
  }
  ingress {
    from_port = 3888
    to_port   = 3888
    protocol  = "tcp"
    security_groups = [
      aws_security_group.app_server.id,
      aws_security_group.engines.id,
      aws_security_group.data_server.id,
      aws_security_group.search_server.id
    ]
    self = true
  }
  ingress {
    from_port = 9092
    to_port   = 9092
    protocol  = "tcp"
    security_groups = [
      aws_security_group.app_server.id,
      aws_security_group.engines.id,
      aws_security_group.data_server.id,
      aws_security_group.search_server.id
    ]
    self = true
  }
}

resource "aws_security_group" "web_server" {
  name   = "appian-web_server-${var.name}"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
}

resource "aws_security_group" "app_server" {
  name   = "appian-app_server-${var.name}"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 8009
    to_port         = 8009
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server.id]
  }
}

# EFS Security Group
resource "aws_security_group" "efs" {
  count       = var.create_efs == true ? 1 : 0
  name        = "appian-efs-${var.name}"
  description = "Appian EFS Security Group for ${var.name}"
  vpc_id      = var.vpc_id
}

# EFS Security Group Rule - Allow 2049 Appian traffic
resource "aws_security_group_rule" "efs_ingress" {
  count                    = var.create_efs == true ? 1 : 0
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.appian.id
  security_group_id        = aws_security_group.efs[0].id
}

resource "aws_efs_file_system" "efs" {
  count                           = var.create_efs == true ? 1 : 0
  creation_token                  = "appian-efs-${var.name}"
  encrypted                       = true
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = "50"
  tags = {
    Name               = "appian-efs-${var.name}"
    appian_environment = var.appian_environment
  }
}

resource "aws_efs_mount_target" "appian" {
  count           = var.create_efs == true ? length(var.efs_subnets) : 0
  file_system_id  = aws_efs_file_system.efs[0].id
  subnet_id       = var.efs_subnets[count.index]
  security_groups = [aws_security_group.efs[0].id]
}

# Create the appian instance
resource "aws_instance" "appian" {
  for_each             = var.appian_instances
  ami                  = var.appian_instances_ami
  key_name             = var.appian_instances_key
  instance_type        = each.value.instance_type
  subnet_id            = each.value.subnet_id
  iam_instance_profile = aws_iam_instance_profile.appian_host.name
  vpc_security_group_ids = compact([
    aws_security_group.appian.id,
    contains(each.value.roles, "engines") ? aws_security_group.engines.id : "",
    contains(each.value.roles, "internal_messaging") ? aws_security_group.internal_messaging.id : "",
    contains(each.value.roles, "data_server") ? aws_security_group.data_server.id : "",
    contains(each.value.roles, "search_server") ? aws_security_group.search_server.id : "",
    contains(each.value.roles, "app_server") ? aws_security_group.app_server.id : "",
  contains(each.value.roles, "web_server") ? aws_security_group.web_server.id : ""])

  root_block_device {
    volume_type = "gp2"
    volume_size = 300
    encrypted   = true
  }

  tags = {
    Name                               = "${each.key}-${var.name}"
    appian_environment                 = var.appian_environment
    appian_hostname                    = each.key
    appian_instance                    = "yes"
    appian_leader                      = contains(each.value.roles, "leader") ? "yes" : "no"
    appian_engines_instance            = contains(each.value.roles, "engines") ? "yes" : "no"
    appian_internal_messaging_instance = contains(each.value.roles, "internal_messaging") ? "yes" : "no"
    appian_data_server_instance        = contains(each.value.roles, "data_server") ? "yes" : "no"
    appian_search_server_instance      = contains(each.value.roles, "search_server") ? "yes" : "no"
    appian_app_server_instance         = contains(each.value.roles, "app_server") ? "yes" : "no"
    appian_web_server_instance         = contains(each.value.roles, "web_server") ? "yes" : "no"
  }
}

resource "aws_security_group" "alb" {
  name        = "appian-alb-${var.name}"
  description = "Appian Application Load Balancer security group for ${var.name}"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "alb_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web_server.id
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_443" {
  count             = local.ssl == true ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Create an appian target group for the ALB
resource "aws_alb_target_group" "appian" {
  name                 = "appian-${var.name}"
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = "10"
  vpc_id               = var.vpc_id
  health_check {
    path                = "/suite"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 5
    timeout             = 4
    matcher             = "200,302"
  }
  stickiness {
    type    = "lb_cookie"
    enabled = true
  }
}

# Attach the appian instance as a target the the ALB target group
resource "aws_lb_target_group_attachment" "appian" {
  for_each         = toset(compact([for key, instance in var.appian_instances : contains(instance.roles, "web_server") ? key : ""]))
  target_group_arn = aws_alb_target_group.appian.id
  target_id        = aws_instance.appian[each.key].id
}

# Create an ALB to front appian.
resource "aws_alb" "appian" {
  name            = "appian-${var.name}"
  internal        = var.load_balancer_internal
  subnets         = var.load_balancer_subnets
  security_groups = [aws_security_group.alb.id]
}

# Conditionally create an ALB listener which forwards 443 traffic to the appian target group.
resource "aws_alb_listener" "https_forward" {
  count             = local.ssl == true ? 1 : 0
  load_balancer_arn = aws_alb.appian.id
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.server_url_certificate_arn
  default_action {
    target_group_arn = aws_alb_target_group.appian.id
    type             = "forward"
  }
}

resource "aws_lb_listener_certificate" "static_url" {
  count           = var.static_url_certificate_arn == "" ? 0 : 1
  listener_arn    = aws_alb_listener.https_forward[0].arn
  certificate_arn = var.static_url_certificate_arn
}

resource "aws_lb_listener_certificate" "dynamic_url" {
  count           = var.dynamic_url_certificate_arn == "" ? 0 : 1
  listener_arn    = aws_alb_listener.https_forward[0].arn
  certificate_arn = var.dynamic_url_certificate_arn
}

# Conditionally create an ALB listener which forwards 80 traffic to the appian target group.
resource "aws_alb_listener" "http_forward" {
  count             = local.ssl == true ? 0 : 1
  load_balancer_arn = aws_alb.appian.id
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.appian.id
    type             = "forward"
  }
}

# Conditionally create an ALB listener which redirects 80 traffic to 443
resource "aws_alb_listener" "http_to_https_redirect" {
  count             = local.ssl == true ? 1 : 0
  load_balancer_arn = aws_alb.appian.id
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.appian.id
    type             = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_302"
    }
  }
}

# Conditionally use an aws_route53_zone data backend to retrieve more information about a hosted zone for which we only have the name.
data "aws_route53_zone" "server_url_hosted_zone" {
  count = var.server_url == "" ? 0 : 1
  name  = var.server_url_hosted_zone
}

# Conditionally create a route53 alias record, resolving our appian url to the dns name of the application load balancer.
resource "aws_route53_record" "server_url" {
  count   = var.server_url == "" ? 0 : 1
  zone_id = data.aws_route53_zone.server_url_hosted_zone[0].zone_id
  name    = var.server_url
  type    = "CNAME"
  ttl     = "5"
  records = [aws_alb.appian.dns_name]
}

# Conditionally use an aws_route53_zone data backend to retrieve more information about a hosted zone for which we only have the name.
data "aws_route53_zone" "static_url_hosted_zone" {
  count = var.static_url == "" ? 0 : 1
  name  = var.static_url_hosted_zone
}

# Conditionally create a route53 alias record, resolving our appian static url to the dns name of the application load balancer.
resource "aws_route53_record" "static_url" {
  count   = var.static_url == "" ? 0 : 1
  zone_id = data.aws_route53_zone.static_url_hosted_zone[0].zone_id
  name    = var.static_url
  type    = "CNAME"
  ttl     = "5"
  records = [aws_alb.appian.dns_name]
}

# Conditionally use an aws_route53_zone data backend to retrieve more information about a hosted zone for which we only have the name.
data "aws_route53_zone" "dynamic_url_hosted_zone" {
  count = var.dynamic_url == "" ? 0 : 1
  name  = var.dynamic_url_hosted_zone
}

# Conditionally create a route53 alias record, resolving our appian dynamic url to the dns name of the application load balancer.
resource "aws_route53_record" "dynamic_url" {
  count   = var.dynamic_url == "" ? 0 : 1
  zone_id = data.aws_route53_zone.dynamic_url_hosted_zone[0].zone_id
  name    = var.dynamic_url
  type    = "CNAME"
  ttl     = "5"
  records = [aws_alb.appian.dns_name]
}
