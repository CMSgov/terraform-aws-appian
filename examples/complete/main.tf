provider "aws" {
  region = "us-east-1"
}

############################################################################################################################
# Set some variables to make this example unique
############################################################################################################################
locals {
  vpc_cidr           = "10.71.0.0/16"
  name               = "complete"
  appian_environment = "ha-appian-complete"
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
# Build infrastructure for a Highly Available and Distributed Appian across 3 availability zones.
############################################################################################################################

module "appian" {
  source = "../../"

  # This name is used in a lot of AWS resource prefixing and suffixing, and doesn't impact the installation.
  name = local.name

  # VPC pulled from the resources above.
  vpc_id = module.vpc.vpc_id

  # Set the appian_environment tag.  This is very useful if using CMSgov's ansible role and dynamic inventory to configure Appian.
  appian_environment = local.appian_environment

  # Define our installation.  Networking rules and configuration are defined by assigning roles to each appian ec2 instance.
  appian_instances_ami = "ami-0b898040803850657"
  appian_instances = {
    "appian1" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[0]
      roles = [
        "engines",
        "data_server",
        "search_server",
        "app_server",
        "leader"
      ]
    }
    "appian2" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[1]
      roles = [
        "engines",
        "data_server",
        "search_server",
        "app_server"
      ]
    }
    "appian3" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[2]
      roles = [
        "engines",
        "data_server",
        "search_server",
        "app_server"
      ]
    }
    "extra_engines1" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[0]
      roles = [
        "engines"
      ]
    }
    "extra_engines2" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[1]
      roles = [
        "engines"
      ]
    }
    "extra_engines3" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[2]
      roles = [
        "engines"
      ]
    }
    "messaging1" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[0]
      roles = [
        "messaging"
      ]
    }
    "messaging2" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[1]
      roles = [
        "messaging"
      ]
    }
    "messaging3" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[2]
      roles = [
        "messaging"
      ]
    }
    "apache1" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[0]
      roles = [
        "web_server"
      ]
    }
    "apache2" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[0]
      roles = [
        "web_server"
      ]
    }
    "apache3" = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.private_subnets[2]
      roles = [
        "web_server"
      ]
    }
  }

  # Build an EFS for our HA installation.  1 is too small, we do it here just to be cheap.
  efs_provisioned_throughput = "1"
  efs_subnets                = [module.vpc.private_subnets[0], module.vpc.private_subnets[1], module.vpc.private_subnets[2]]

  # Allow the ALB to balance traffic in 1 or more public subnets
  load_balancer_subnets = module.vpc.public_subnets

  # Set server_url and server_url_hosted_zone.  Leave blank to use the Appian load balancer's automatically generated DNS to access Appian.
  server_url             = "${local.name}.ha-appian.examples.cl-demo.com"
  server_url_hosted_zone = "cl-demo.com"

  # Specify a certificate, valid for server_url and server_url_hosted_zone.  Leave blank if you don't need/want TLS.
  server_url_certificate_arn = "arn:aws:acm:us-east-1:008087533974:certificate/9f5b5bed-fb2f-452e-af0b-606326f5a239"

  # Add certificate and route53 entry to allow the ALB to receive and forward traffic to a static domain.
  static_url                 = "${local.name}.iac-sandbox-static.com"
  static_url_hosted_zone     = "iac-sandbox-static.com"
  static_url_certificate_arn = "arn:aws:acm:us-east-1:008087533974:certificate/c01342fd-8d04-48e0-8424-b2b93c6b9d0c"

  # Add certificate and route53 entry to allow the ALB to receive and forward traffic to a dynamic domain.
  dynamic_url                 = "${local.name}.iac-sandbox-dynamic.com"
  dynamic_url_hosted_zone     = "iac-sandbox-dynamic.com"
  dynamic_url_certificate_arn = "arn:aws:acm:us-east-1:008087533974:certificate/43eb4830-b0c5-4a64-bae2-5889233eb925"

  create_new_db = false
}

############################################################################################################################
# Allow SSM to manage access to the hosts.  This is entirely optional, but a good pattern for private host access.
# We told the module to build private hosts, without port 22 open, and without an SSH key.
# So, we will use SSM to access the hosts.  Again... this is optional.  Feel free to use ssh keys and public subnets.
############################################################################################################################

resource "aws_iam_policy" "ssm" {
  name   = "${local.name}-admin"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "ssm" {
  name       = "${local.name}-ssm-attachment"
  roles      = [module.appian.appian_host_role]
  policy_arn = aws_iam_policy.ssm.arn
}
