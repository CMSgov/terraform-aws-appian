Terraform Module: Appian
=========


Terraform module which creates infrastructure for Appian installations:
- Single host configurations are supported.
- Highly available and distributed (HA/D) configurations are supported.
- EFS is created for HA/D configurations.

Optional features:
- As a convenience, the module can optionally create an RDS MySQL installation to serve as the Appian system data store.
- TLS encryption; a certificate from ACM can be loaded onto the Application Load Balancer fronting Appian to provide encryption en route.
- DNS management using Route53; if you have access to an AWS Route53 hosted zone, this module can assign a name to the Application Load Balancer.


## Terraform versions

Terraform 0.12 is supported as of release 2.0.0.

Terraform 0.11 is supported in 1.0 releases.  Terraform 0.11 support and 1.0 releases's will not be maintained.


## Usage
See a highly available, distributed example [here!](examples/complete)
Or check out a simpler [single host example](examples/simple).


```hcl
module "appian" {
  source                     = "git::ssh://git@github.com/CMSgov/terraform-aws-appian.git"
  name                       = "demoappian"
  server_url                 = "demoappian.myroute53hostedzone.com"
  server_url_hosted_zone     = "myroute53hostedzone.com"
  server_url_certificate_arn = "arn:aws:acm:us-east-1:123456789:certificate/xxxxxxxxxx"
  key_name                   = "myEc2KeyPair"
  vpc_id                     = "vpc-1234"
  subnet_id                  = "subnet-8675309"
  ami_id                     = "ami-0b898040803850657"
  db_subnets                 = ["subnet-1234", "subnet-5678"]
  db_username                = "myuser"
  db_password                = "makeThisGood"
}
```


## Examples
See a common, complete (with vpc) example [here!](examples/common)
Or check out a more [advanced](examples/advanced) implementation that includes a custom, user supplied system data store and an additional RDS for business data.


## Contributing / To-Do

See current open [issues](https://github.com/CMSgov/terraform-aws-appian/issues)

Feel free to open any new issues for defects or enhancements.


## Notes

- As always, this is a work in progress.  Please contribute.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| appian\_environment | This is a tag applied to most resources.  This tag and its value can be used later to find resources (if you're going to run ansible to configure appian, you will want to remember this value) | string | n/a | yes |
| appian\_instances | A map containing information about the appian instances and topology. | object | n/a | yes |
| appian\_instances\_ami | ID of the ami for the appian instances | string | n/a | yes |
| appian\_instances\_key | EC2 key pair to associate with the launched appian instances. | string | `""` | no |
| create\_efs | Create EFS for Appian shared folder requirements; should be set to false if building Appian in a single host configuration, which has no shared folder requirements. | bool | `"true"` | no |
| create\_new\_db | Indicates whether a new RDS should be created for the Appian system data store, or if an existing RDS and it's connection info will be provided. | bool | `"true"` | no |
| db\_allocated\_storage | RDS MySQL's allocated storage in gigabytes.  Only applies if create_new_db is true. | string | `"20"` | no |
| db\_instance\_class | The db instance type for RDS.  Only applies if create_new_db is true. | string | `"db.t3.medium"` | no |
| db\_password | Desired Oracle RDS password.  Only applies if create_new_db is true. | string | `""` | no |
| db\_subnets | The subnets for the Oracle RDS; there must be two and they must be private.  Only applies if create_new_db is true. | list | `[]` | no |
| db\_username | Desired Oracle RDS username.  Only applies if create_new_db is true. | string | `""` | no |
| dynamic\_url | The FQDN to be configured as Appians dynamic server. | string | `""` | no |
| dynamic\_url\_certificate\_arn | Optional certificate to apply to the ALB, valid for appian's dynamic content url. | string | `""` | no |
| dynamic\_url\_hosted\_zone | The Route53 hosted zone for dynamic_url. | string | `""` | no |
| efs\_provisioned\_throughput | Provisioned througput in MB/s of Appian's EFS. | string | `"50"` | no |
| efs\_subnets | The subnets where EFS mount targets will be created.  You must create one and only one mount target for each availability zone that contains an Appian.  If your Appian's are in separate subnets and each subnet is in a separate AZ, then this is simply a list of all appian_instances subnets.  Required if create_efs is true. | list | `[]` | no |
| hosted\_zone | A Route53 hosted zone you control.  Set if you'd like to make a Route53 record pointing to appian.  If hosted_zone is set, fqdn is required. | string | `""` | no |
| load\_balancer\_internal | Set to true to create a publicly-resolvable but non-publicly-accessible load balancer for appian.  If set to true, load_balancer_subnets must be given private subnets. | bool | `"false"` | no |
| load\_balancer\_subnets | The subnets in which the Application Load Balancer will be available.  A list of at least two is required.  If private subnets are used, load_balancer_internal must be set to true. | list | n/a | yes |
| name | Sensible name for this Appian installation.  This is used widely in AWS tagging and naming, but does not affect the application. | string | n/a | yes |
| server\_url | The FQDN with which to configure Appian; leave blank to simnply access Appian with the generated DNS name of the load balancer.  If set, server_url_hosted_zone is required. | string | `""` | no |
| server\_url\_certificate\_arn | Certificate to apply to the .  Setting this effectively enables SSL.  The certificate's domain must be valid for the set server_url and server_url_hosted_one.  If set, server_url and server_url_hosted_zone are required. | string | `""` | no |
| server\_url\_hosted\_zone | The Route53 hosted zone in which to make an entry for server_url.  If set, server_url is required | string | `""` | no |
| static\_url | The FQDN to be configured as Appians static server. | string | `""` | no |
| static\_url\_certificate\_arn | Optional certificate to apply to the ALB, valid for appian's static content url. | string | `""` | no |
| static\_url\_hosted\_zone | The Route53 hosted zone for static_url. | string | `""` | no |
| vpc\_id | The ID of the VPC into which the appian instance will be launched. | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| appian\_host\_role | The Appian EC2 instance(s) host role.  This can be used to attach additional policies externally. |
| appian\_host\_security\_group | The security group attached to the EC2 Appian Host.  This can be used to attach new rules outside the module. |
| appiands\_security\_group | The security group attached to the RDS serving as the Appian system data store.  This will not have a value if you brought your own RDS system data store instead of having the module build it for you. |
| efs\_id | ID of the EFS created for Appian's shared folder needs. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->


## License

[![License](https://img.shields.io/badge/License-CC0--1.0--Universal-blue.svg)](https://creativecommons.org/publicdomain/zero/1.0/legalcode)

See [LICENSE](LICENSE.md) for full details.

```text
As a work of the United States Government, this project is
in the public domain within the United States.

Additionally, we waive copyright and related rights in the
work worldwide through the CC0 1.0 Universal public domain dedication.
```
