variable "vpc-cidr" {}
variable "environment" {}
variable "private-subnets" {
  type = "list"
}

variable "target-group-deregistration-delay" {}

variable "public-subnets" {
  type = "list"
}

variable "service-desired-count" {
  default = 2
}

variable "app" {}
variable "container-name" {}
variable "container-port" {}
variable "cpu-task" {}
variable "memory-task" {}
variable "service-role-file" {}
variable "task-definition-file" {}
variable "alb-port" {}
variable "alb-protocol" {
  default = "HTTP"
}
variable "healthy-threshold" {}
variable "health-check-interval" {}
variable "health-check-protocol" {
  default = "HTTP"
}
variable "health-check-path" {
  default = "/"
}