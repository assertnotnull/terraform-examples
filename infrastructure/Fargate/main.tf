data "aws_vpc" "main-vpc" {
  cidr_block = "${var.vpc-cidr}"
}

resource "aws_security_group" "app-alb" {
  name = "${var.app}-alb-${var.environment}"
  vpc_id = "${data.aws_vpc.main-vpc.id}"

  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    protocol = "TCP"
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app-task" {
  name = "${var.app}-task-${var.environment}"
  vpc_id = "${data.aws_vpc.main-vpc.id}"
  ingress {
    from_port = "${var.container-port}"
    protocol = "TCP"
    to_port = "${var.container-port}"
    security_groups = ["${aws_security_group.app-alb.id}"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app" {
  name = "${var.app}-${var.environment}"
  internal = false
  load_balancer_type = "application"
  security_groups = ["${aws_security_group.app-alb.id}"]
  subnets = ["${var.public-subnets}"]

  enable_deletion_protection = true

  tags {
    Project = "${var.app}"
    Environement = "${var.environment}"
  }
}

resource "aws_alb_target_group" "app" {
  name = "${var.app}-target-group-${var.environment}"
  port = "${var.alb-port}"
  protocol = "HTTP"
  vpc_id = "${data.aws_vpc.main-vpc.id}"
  target_type = "ip"
  deregistration_delay = "${var.target-group-deregistration-delay}"

  health_check {
    healthy_threshold = "${var.healthy-threshold}"
    interval = "${var.health-check-interval}"
    protocol = "${var.health-check-protocol}"
    path = "${var.health-check-path}"
  }
}

resource "aws_alb_listener" "app" {
  default_action {
    target_group_arn = "${aws_alb_target_group.app.id}"
    type = "forward"
  }
  load_balancer_arn = "${aws_lb.app.arn}"
  port = "${var.alb-port}"
  protocol = "${var.alb-protocol}"
}

resource "aws_ecs_cluster" "app" {
  name = "${var.app}-${var.environment}"
}

resource "aws_ecs_task_definition" "app" {
  container_definitions = "${var.task-definition-file}"
  family = "${var.app}"
  network_mode = "awsvpc"
  execution_role_arn = "arn:aws:iam::511376436002:role/ecsTaskExecutionRole"
  task_role_arn = "${aws_iam_role.app.arn}"
  requires_compatibilities = ["FARGATE"]
  cpu = "${var.cpu-task}"
  memory = "${var.memory-task}"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "/ecs/${var.app}-${var.environment}"

  tags {
    Project = "${var.app}"
    Environement = "${var.environment}"
  }
}

resource "aws_iam_role" "app" {
  name = "${var.app}-ecs-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "app" {
  policy = "${var.service-role-file}"
  role = "${aws_iam_role.app.id}"
}

resource "aws_ecs_service" "app" {
  name = "${var.app}"
  cluster = "${aws_ecs_cluster.app.id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count = "${var.service-desired-count}"
  launch_type = "FARGATE"

  network_configuration {
    security_groups = ["${aws_security_group.app-task.id}"]
    subnets = ["${var.public-subnets}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.app.arn}"
    container_name = "${var.container-name}"
    container_port = "${var.container-port}"
  }

  depends_on = ["aws_alb_listener.app"]
}