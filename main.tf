
//----------------------------------------------------------------------------
// VPC

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "egress-service-${var.deployment_name}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "egress-service-${var.deployment_name}"
  }
}


//----------------------------------------------------------------------------
// Subnets

resource "aws_subnet" "public" {
  count      = local.az_count

  vpc_id     = aws_vpc.main.id
  availability_zone = element(var.availability_zone_names, count.index)

  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)

  tags = {
    Name = "egress-service-public-${count.index}-${var.deployment_name}"
  }
}


resource "aws_subnet" "private" {
  count      = local.az_count

  vpc_id     = aws_vpc.main.id
  availability_zone = element(var.availability_zone_names, count.index)

  // Adding the az_count starts the private IP ranges straight after the public ones
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + local.az_count)

  tags = {
    Name = "egress-service-private-${count.index}-${var.deployment_name}"
  }
}


//----------------------------------------------------------------------------
// NAT Gateway

resource "aws_eip" "main" {
  count     = local.az_count
  vpc       = true
  tags = {
    Name = "egress-service-${count.index}-${var.deployment_name}"
  }
}

resource "aws_nat_gateway" "main" {
  count      = local.az_count

  subnet_id = aws_subnet.public[count.index].id
  allocation_id = aws_eip.main[count.index].id

  tags = {
    Name = "egress-service-${count.index}-${var.deployment_name}"
  }

  /*
    It's recommended to denote that the NAT Gateway depends on the Internet Gateway for the VPC
    in which the NAT Gateway's subnet is located. - Terrform docs.
  */
  depends_on = [aws_internet_gateway.main]
}


//----------------------------------------------------------------------------
// Route Tables

/**
  The default table should end up never associated with any subnet.
  We include it here to was can set its name.
*/
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  tags = {
    Name = "egress-service-default-${var.deployment_name}"
  }
}


/**
  We only need a single public route as its identical for all public subnets
*/
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  dynamic "route" {
    for_each = var.application_cidr_blocks
    content {
      cidr_block = route.value
      transit_gateway_id = aws_ec2_transit_gateway.main.id
    }
  }

  tags = {
    Name = "egress-service-public-${var.deployment_name}"
  }
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}


/**
  Each private subnet requires its own route as each point to its own NAT Gateway.
*/
resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "egress-service-private-${count.index}-${var.deployment_name}"
  }
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}


//----------------------------------------------------------------------------
// Transit Gateway

resource "aws_ec2_transit_gateway" "main" {
  tags = {
    Name = "egress-service-${var.deployment_name}"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  vpc_id             = aws_vpc.main.id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  subnet_ids         = aws_subnet.private.*.id

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "egress-service-internal-${var.deployment_name}"
  }
}


//--------------------------------------------------------------------------------
// Route for traffic that is returning from the Internet, via the Egress Service.

/**
  This route table will contain an entry for each client VPC that connects to the egress service.
*/
resource "aws_ec2_transit_gateway_route_table" "returning_traffic" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "egress-service-returning-traffic-${var.deployment_name}"
    Direction = "returning"
  }
}

/**
  And attach it to the egress VPC (and only the egress VPC)
*/
resource "aws_ec2_transit_gateway_route_table_association" "returning_traffic" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.returning_traffic.id
}


//--------------------------------------------------------------------------------
// Route for traffic that's heading out towards the Internet

/**
  This route table has a fixed set of routes. i.e. no furhter routes should be added.
*/
resource "aws_ec2_transit_gateway_route_table" "outgoing_traffic" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "egress-service-outgoing-traffic-${var.deployment_name}"
    Direction = "outgoing"
  }
}

/**
  All traffic for the default route should be passed to the egress VPC
*/
resource "aws_ec2_transit_gateway_route" "outgoing_traffic_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.outgoing_traffic.id
}

/**
  AWS Recommends you blackhole all RFC1918 blocks (private IP addresses)
*/
resource "aws_ec2_transit_gateway_route" "outgoing_traffic_rfc1918_addresses" {
  for_each = toset(["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"])
  destination_cidr_block         = each.value
  blackhole                      = true
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.outgoing_traffic.id
}
