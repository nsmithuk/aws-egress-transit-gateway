
// Attach this VPC to the TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  vpc_id             = data.aws_vpc.client.id
  subnet_ids         = var.subnet_ids
  transit_gateway_id = data.aws_ec2_transit_gateway.egress_service.id

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "egress-client-${var.deployment_name}"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "test_three" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.egress_outgoing_traffic.id
}


// Add a route to `egress` route table, pointing back to me
resource "aws_ec2_transit_gateway_route" "test_three" {
  destination_cidr_block         = data.aws_vpc.client.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.egress_returning_traffic.id
}
