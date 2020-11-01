# AWS Egress Transit Gateway

An example of how an Egress Service could be setup in AWS using a Transit Gateway.

This repository includes:
1. The Egress Service itself, in the root of the repository.
2. A Terraform module that can be dropped into other services which wish to use the Egress Service, in [/client](/client)
3. An example of the client being used, in [/client-example](/client-example)

## Terminology

* **Client VPC**: The VPC of a service that's making use of the *Egress Service*.
* **Egress Service VPC**: The VPC owned by the Egress Service, through which egress traffic passes. It contains one NAT Gateway per AZ used.
* **Egress Service Transit Gateway**: - An AWS Transit Gateway that's attached to the *Egress Service VPC*. The route table for traffic originating from a *Client VPC* points to the *Egress Service VPC*.
* **Egress Service**: The *Egress Service VPC* and the *Egress Service Transit Gateway* combined.

## Network Recommendations

Routing is much simpler to manage if you segregate your networks by class. It is common to use Class A or B networks for *Client VPCs*, and a Class C network for the Egress Service VPC.

When setup in this fashion, we can use large sweeping CIDR blocks, which allows for a simpler configuration.

## Variables

Name | Default | Description
---- | ------- | -----------
deployment_name | *None, a value is required* | The Egress Service is namespaced by *deployment_name*, allowing for multiple Egress Services to be deployed if desired.
vpc_cidr_block | `192.168.255.0/24` | The CIDR block used for the *Egress Service VPC*. A Class C network is recommended.
application_cidr_blocks | `["10.0.0.0/8"]` | A list of CIDR Blocks used by the *Client VPCs*. If all *Client VPCs* share the same network class, large `/8` (Class A) or `/12` (Class B) blocks can be used.
availability_zone_names | `["eu-west-2a", "eu-west-2b", "eu-west-2c"]` | AWS recommends that at least 3 AZs be used in production systems. A smaller range could be used for development and testing environments. 

## Running

**Requires Terraform v0.13**

To bring up an instance of the *Egress Service*:
```bash
terraform init
terraform apply -var='deployment_name=main'
```

To bring up an instance of the Example Service, which uses the Egress Service client.
```bash
cd client-example
terraform init
terraform apply -var='deployment_name=example' -var='egress_service_transit_gateway_id=<Gateway ID output from the above Terraform apply>'
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
