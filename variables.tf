
variable "deployment_name" {
  type = string
  description = "The namespace of this specific deployment of the vpc-egress-service"
}

variable "vpc_cidr_block" {
  type = string
  default = "192.168.255.0/24"
  description = "CIDR block to use for the Egress Service's VPC. It's recommended to use a different network class to your main set of VPCs. Typically a Class C network works well. e.g. 192.168.0.0/24"
}

variable "application_cidr_blocks" {
  type = list(string)
  default = ["10.0.0.0/8"]
  description = "A list of CIDR blocks used by the application VPCs. This will typically be either a Class A or B RFC1918 block."
}

data "aws_availability_zones" "default" {}
variable "availability_zone_names" {
  type = list(string)
  default = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  description = "A list of one of more availability zones. A NAT gateway will be created in each zone. AWS recommends using 3 or more zones for production systems."
}

locals {
  // THe number of AZs we are using
  az_count = length(var.availability_zone_names)
}
