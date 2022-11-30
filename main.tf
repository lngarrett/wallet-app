provider "aws" {
  region = "us-east-1"
}

# data "template_file" "task_template_wallet_app" {
#   template = "${file("./templates/task.json.tpl")}"

#   vars = {
#     app_cpu           = var.cpu
#     app_memory        = var.memory
#     database_password = aws_secretsmanager_secret.database_password_secret.arn
#   }
# }

resource "aws_ecs_cluster" "app" {
  name = "app"
}

resource "aws_ecs_service" "wallet-app" {
  name            = "wallet-app"
  task_definition = aws_ecs_task_definition.wallet-app.arn
  cluster         = aws_ecs_cluster.app.id
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    assign_public_ip = false

    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_api.id,
    ]

    subnets = [
      aws_subnet.private_d.id,
      aws_subnet.private_e.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wallet_app.arn
    container_name   = "wallet-app"
    container_port   = "8080"
  }
}

resource "aws_cloudwatch_log_group" "wallet-app" {
  name = "/ecs/wallet-app"
}

resource "aws_ecs_task_definition" "wallet-app" {
  family = "wallet-app"

#   container_definitions = data.template_file.task_template_wallet_app.rendered
  container_definitions = <<EOF
  [
    {
      "name": "wallet-app",
      "image": "939121955975.dkr.ecr.us-east-1.amazonaws.com/wallet-app:latest",
      "secrets": [
        {
            "valueFrom": "${aws_secretsmanager_secret.api_key.arn}",
            "name": "API_KEY"
        }
      ],
      "portMappings": [
        {
          "containerPort": 8080
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "us-east-1",
          "awslogs-group": "/ecs/wallet-app",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  EOF

  execution_role_arn = aws_iam_role.wallet_app_task_execution_role.arn
  cpu = 256
  memory = 512
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
}

resource "aws_iam_role" "wallet_app_task_execution_role" {
  name               = "wallet-app-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.wallet_app_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}

resource "aws_secretsmanager_secret" "api_key" {
  name = "/wallet-app/api-key"
}

resource "aws_iam_policy" "apikey_policy_secretsmanager" {
  name = "password-policy-secretsmanager"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_secretsmanager_secret.api_key.arn}"
        ]
      }
    ]
  }
  EOF
}

resource aws_iam_role_policy_attachment secret_access {
   role       = aws_iam_role.wallet_app_task_execution_role.name
   policy_arn = aws_iam_policy.apikey_policy_secretsmanager.arn
 }

## Network

resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_d" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.1.0/25"
  availability_zone = "us-east-1d"

  tags = {
    "Name" = "public | us-east-1d"
  }
}

resource "aws_subnet" "private_d" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.2.0/25"
  availability_zone = "us-east-1d"

  tags = {
    "Name" = "private | us-east-1d"
  }
}

resource "aws_subnet" "public_e" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.1.128/25"
  availability_zone = "us-east-1e"

  tags = {
    "Name" = "public | us-east-1e"
  }
}

resource "aws_subnet" "private_e" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.2.128/25"
  availability_zone = "us-east-1e"

  tags = {
    "Name" = "private | us-east-1e"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    "Name" = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    "Name" = "private"
  }
}

resource "aws_route_table_association" "public_d_subnet" {
  subnet_id      = aws_subnet.public_d.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_d_subnet" {
  subnet_id      = aws_subnet.private_d.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_e_subnet" {
  subnet_id      = aws_subnet.public_e.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_e_subnet" {
  subnet_id      = aws_subnet.private_e.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = aws_subnet.public_d.id
  allocation_id = aws_eip.nat.id

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_ngw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}

resource "aws_security_group" "http" {
  name        = "http"
  description = "HTTP traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "https" {
  name        = "https"
  description = "HTTPS traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress_all" {
  name        = "egress-all"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_api" {
  name        = "ingress-api"
  description = "Allow ingress to API"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


## Load Balancer

resource "aws_lb_target_group" "wallet_app" {
  name        = "wallet-app"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.app_vpc.id

  health_check {
    enabled = true
    path    = "/"
  }

  depends_on = [aws_alb.wallet_app]
}

resource "aws_alb" "wallet_app" {
  name               = "wallet-app-lb"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public_d.id,
    aws_subnet.public_e.id,
  ]

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_alb_listener" "wallet_app_http" {
  load_balancer_arn = aws_alb.wallet_app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
 }

}

resource "aws_acm_certificate" "wallet_app" {
  domain_name       = "wallet-app.whisk.ee"
  validation_method = "DNS"
}

resource "aws_alb_listener" "wallet_app_https" {
  load_balancer_arn = aws_alb.wallet_app.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.wallet_app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wallet_app.arn
  }
}

output "domain_validations" {
  value = aws_acm_certificate.wallet_app.domain_validation_options
}

output "alb_url" {
  value = "http://${aws_alb.wallet_app.dns_name}"
}