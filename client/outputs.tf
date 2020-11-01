
output "egress_service_transit_gateway_id" {
  value = data.aws_ec2_transit_gateway.egress_service.id
}
