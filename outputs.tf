
/**
  The Transit Gateway ID towhich other client VPCs should connect.
*/
output "egress_service_transit_gateway_id" {
  value = aws_ec2_transit_gateway.main.id
}
