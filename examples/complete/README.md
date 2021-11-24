# Complete Appian Terraform example

This is a working terraform example that creates infrastructure for a Highly Available and Distributed Appian installation
This builds:
- 3 EC2 instances to hold the Appian app servers, data servers, search servers, and engines servers
- 3 EC2 instances to serve as Kafka/Zookeeper servers.
- 3 additional EC2 instances to hold additional execution and analytics engines.
- 3 EC2 instances to serve as Apache web servers in front of the application servers.
- All EC2 instances are distributed across availability zones for a sensible HA setup.
- An EFS installation to meet the shared folder requirements of Highly Available / Distributed Appian installations.
- Application Load Balancer with certificate to front the web servers, allowing for TLS encryption and termination.
- A route 53 entry to give the ALB a user friendly name.
- Additional static and dynamic route53 entries to allow Appian to separate static and dynamic traffic as needed.
- An SSH key is not specified, nor is port 22 open.  An SSM policy is added to allow private host access.  This is optional.

## Usage

To use this module, would would need to:
1. Update account specific variables to make sense for your account; namely, the certificate name(s) and server url(s) will need to be updated.
2. Run:
```bash
$ terraform init
$ terraform apply
```

## Notes

- This example is meant to flex the module.  The choice to put Kafka/Zookeeper on separate servers was driven only from a desire to be as complicated as we can be, not from common Appian requirements.  The point is:  Appian allows you to run Kafka/Zookeeper on separate servers, so this module should allow it too; so, we test it here.  Likewise, the choice to add additional engine servers is only done to flex the module.  It is entirely valid (and more common) to run a (simpler) Highly Available setup with only 3 EC2 instances, each running web_server, app_server, search_server, data_server, and engines.
- Instances are built as t3a.nano instance types.  This is much too small to serve as part of any Appian installation.  This size was chosen simply to save money when testing this module repeatedly.  You will need a bigger instance type.
- The selected efs_provisioned_throughput is 1 MB/s.  This is likely not enough for a Highly Available Appian installation.  This size was chosen to save money when testing this module repeatedly.  Use a bigger value or the default value of 50.
