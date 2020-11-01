variable "deployment_name" {
  type = string
  description = "The namespace of this example client service."
}


variable "egress_service_transit_gateway_id" {
  type = string
  description = "The ID of the Transit Gateway owned by the Egress Service"
}
