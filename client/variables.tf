
variable "deployment_name" {
  type = string
  description = "The namespace of the client deployment"
}

variable "vpc_id" {
  type = string
  description = "The ID of the client VPC"
}

variable "subnet_ids" {
  type = list(string)
  description = "A list of subnet, one per AZ that we use, in which we should create the Transit Gateway ENIs"
}

variable "egress_service_transit_gateway_id" {
  type = string
  description = "The ID of the Transit Gateway owned by the Egress Service"
}

//------------------------------------------------------------------------
// We can derive the other required variables

data "aws_vpc" "client" {
  id = var.vpc_id
}

data "aws_ec2_transit_gateway" "egress_service" {
  id = var.egress_service_transit_gateway_id
}

/**
  The route table to we need to associate
*/
data "aws_ec2_transit_gateway_route_table" "egress_outgoing_traffic" {

  filter {
    name   = "transit-gateway-id"
    values = [data.aws_ec2_transit_gateway.egress_service.id]
  }
  filter {
    name   = "tag:Direction"
    values = ["outgoing"]
  }

}

/**
  The route table which we must add 'our' CIDR block to, so that returning traffic is routed to 'us'.
*/
data "aws_ec2_transit_gateway_route_table" "egress_returning_traffic" {

  filter {
    name   = "transit-gateway-id"
    values = [data.aws_ec2_transit_gateway.egress_service.id]
  }
  filter {
    name   = "tag:Direction"
    values = ["returning"]
  }

}
