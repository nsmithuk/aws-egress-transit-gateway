
data "aws_availability_zones" "default" {}

//------------------------------------------------------------------------------------
// Step 1 - Setup your VPC as per normal.

resource "aws_vpc" "example" {
  cidr_block = "10.255.0.0/16"

  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "example-client-service-${var.deployment_name}"
  }
}

resource "aws_subnet" "private" {
  count      = length(data.aws_availability_zones.default.names)

  vpc_id     = aws_vpc.example.id
  availability_zone = element(data.aws_availability_zones.default.names, count.index)
  cidr_block = cidrsubnet(aws_vpc.example.cidr_block, 8, count.index)

  tags = {
    Name = "example-client-service-${count.index}-${var.deployment_name}"
  }
}

//------------------------------------------------------------------------------------
// Step 2 - Include the egress ervice client module, passing is the required details

module "tgw_connection" {
  source = "github.com/nsmithuk/aws-egress-transit-gateway/client"

  // Our deployment name, so the client resources will mathch.
  deployment_name = var.deployment_name

  // The VPC ID
  vpc_id = aws_vpc.example.id

  // One private subnet per AZ
  subnet_ids = aws_subnet.private.*.id

  // The ID of the Transit Gateway. The value will need to be looked up.
  egress_service_transit_gateway_id = var.egress_service_transit_gateway_id
}


//------------------------------------------------------------------------------------
// Step 3 - Add the TGW as the default route to all relevant route tables.

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.example.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"

    // It's safer here to use the module output as it means the gateway will already have been validated by this point.
    transit_gateway_id = module.tgw_connection.egress_service_transit_gateway_id
  }

  tags = {
    Name = "example-client-service-default-${var.deployment_name}"
  }
}
