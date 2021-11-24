provider "aws" {
  region = "us-east-1"
}

############################################################################################################################
# Set some variables to make this example unique
############################################################################################################################
locals {
  vpc_cidr           = "10.71.0.0/16"
  name               = "simple"
  appian_environment = "ha-appian-simple"
}

############################################################################################################################
# Build a VPC for this example
############################################################################################################################
data "aws_availability_zones" "available" {}

resource "null_resource" "subnets" {
  count = length(data.aws_availability_zones.available.names)
  triggers = {
    private_subnet = cidrsubnet(local.vpc_cidr, 8, count.index + 1)
    public_subnet  = cidrsubnet(local.vpc_cidr, 8, count.index + 101)
  }
}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "2.9.0"
  name                 = "vpc-cl-appian-tf-example-${local.name}"
  cidr                 = local.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = null_resource.subnets.*.triggers.private_subnet
  public_subnets       = null_resource.subnets.*.triggers.public_subnet
  enable_dns_hostnames = true
  enable_dns_support   = true
  # Set to alse to save cost; in reality, you would need to provide outbound internet to install/configure appian.
  enable_nat_gateway = false
}

############################################################################################################################
# Build infrastructure for a simple, single host Appian installation
############################################################################################################################

module "appian" {
  source = "../../"

  # This name is used in a lot of AWS resource prefixing and suffixing, and doesn't impact the installation.
  name = local.name

  # VPC pulled from the resources above.
  vpc_id = module.vpc.vpc_id

  # Set the appian_environment tag.  This is very useful if using CMSgov's ansible role and dynamic inventory to configure Appian.
  appian_environment = local.appian_environment

  # Define our installation.  Here, we specify a simple, single host installation.
  appian_instances_key = "examples"
  appian_instances_ami = "ami-0b898040803850657"
  appian_instances = {
    "appian1" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.public_subnets[0]
      roles = [
        "engines",
        "data_server",
        "search_server",
        "app_server",
        "web_server",
        "leader"
      ]
    }
  }

  # Do not create an EFS installation; single host appian configurations don't require shared folders.
  create_efs = false

  # Allow the ALB to balance traffic in 1 or more public subnets
  load_balancer_subnets = module.vpc.public_subnets

  # Set server_url and server_url_hosted_zone.  Leave blank to use the Appian load balancer's automatically generated DNS to access Appian.
  server_url             = "${local.name}.ha-appian.examples.cl-demo.com"
  server_url_hosted_zone = "cl-demo.com"

  # Specify a certificate, valid for server_url and server_url_hosted_zone.  Leave blank if you don't need/want TLS.
  server_url_certificate_arn = "arn:aws:acm:us-east-1:008087533974:certificate/9f5b5bed-fb2f-452e-af0b-606326f5a239"

  # Let's let the module create a system data store for us.
  db_subnets  = module.vpc.private_subnets
  db_username = "dbuser"
  db_password = "badPassword"
  # Use a very small db to save cost when building this example repeatedly.
  db_instance_class = "db.t3.medium"
}

############################################################################################################################
# Below are resources allowing SSH from the Terraform runner.  Since this is an example, we will simply find the terraform
# runner's public IP and add a security group rule to allow it.
# Don't use icanhazip in non-dev environments.
############################################################################################################################

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group_rule" "appian_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.appian.appian_host_security_group
}
