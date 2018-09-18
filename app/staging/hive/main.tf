terraform {
  backend "s3" {
    bucket = "company-terraform"
    key = "infrastructure/Fargate/production/hive/terraform.tfstate"
    region = "us-east-1"
    profile = "aws"
    encrypt = "true"
  }
}

provider "aws" {
  region = "us-east-1"
}

module "app" {
  source = "../../../infrastructure/Fargate"
  app = "hive"
  environment = "staging"
  private-subnets = ["subnet-xxxx"]
  public-subnets = ["subnet-xxxx"]
  task-definition-file = "${file("${path.cwd}/task-definition.json")}"
  service-role-file = "${file("${path.cwd}/service-role.json")}"
  container-port = 4000
  alb-port = 80
  container-name = "app-graphql"
  cpu-task = "256"
  memory-task = "512"
  target-group-deregistration-delay = "30"
  vpc-cidr = "x.x.x.x/20"

  healthy-threshold = 3
  health-check-interval = 30
  health-check-protocol = "HTTP"
  health-check-path = "/"
}