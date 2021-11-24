variable "hosted_zone" {
  description = "A Route53 hosted zone you control.  Set if you'd like to make a Route53 record pointing to appian.  If hosted_zone is set, fqdn is required."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "The ID of the VPC into which the appian instance will be launched."
  type        = string
}

variable "name" {
  description = "Sensible name for this Appian installation.  This is used widely in AWS tagging and naming, but does not affect the application."
  type        = string
}

variable "create_new_db" {
  type        = bool
  description = "Indicates whether a new RDS should be created for the Appian system data store, or if an existing RDS and it's connection info will be provided."
  default     = true
}

variable "db_instance_class" {
  description = "The db instance type for RDS.  Only applies if create_new_db is true."
  type        = string
  default     = "db.t3.medium"
}

variable "db_subnets" {
  description = "The subnets for the Oracle RDS; there must be two and they must be private.  Only applies if create_new_db is true."
  type        = list
  default     = []
}

variable "db_username" {
  description = "Desired Oracle RDS username.  Only applies if create_new_db is true."
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Desired Oracle RDS password.  Only applies if create_new_db is true."
  type        = string
  default     = ""
}

variable "db_allocated_storage" {
  description = "RDS MySQL's allocated storage in gigabytes.  Only applies if create_new_db is true."
  type        = string
  default     = 20
}

variable "load_balancer_subnets" {
  description = "The subnets in which the Application Load Balancer will be available.  A list of at least two is required.  If private subnets are used, load_balancer_internal must be set to true."
  type        = list
}

variable "load_balancer_internal" {
  description = "Set to true to create a publicly-resolvable but non-publicly-accessible load balancer for appian.  If set to true, load_balancer_subnets must be given private subnets."
  type        = bool
  default     = false
}

variable "server_url" {
  description = "The FQDN with which to configure Appian; leave blank to simnply access Appian with the generated DNS name of the load balancer.  If set, server_url_hosted_zone is required."
  type        = string
  default     = ""
}

variable "server_url_hosted_zone" {
  description = "The Route53 hosted zone in which to make an entry for server_url.  If set, server_url is required"
  type        = string
  default     = ""
}

variable "server_url_certificate_arn" {
  description = "Certificate to apply to the .  Setting this effectively enables SSL.  The certificate's domain must be valid for the set server_url and server_url_hosted_one.  If set, server_url and server_url_hosted_zone are required."
  type        = string
  default     = ""
}

variable "static_url" {
  description = "The FQDN to be configured as Appians static server."
  type        = string
  default     = ""
}

variable "static_url_hosted_zone" {
  description = "The Route53 hosted zone for static_url."
  type        = string
  default     = ""
}

variable "static_url_certificate_arn" {
  description = "Optional certificate to apply to the ALB, valid for appian's static content url."
  type        = string
  default     = ""
}

variable "dynamic_url" {
  description = "The FQDN to be configured as Appians dynamic server."
  type        = string
  default     = ""
}

variable "dynamic_url_hosted_zone" {
  description = "The Route53 hosted zone for dynamic_url."
  type        = string
  default     = ""
}

variable "dynamic_url_certificate_arn" {
  description = "Optional certificate to apply to the ALB, valid for appian's dynamic content url."
  type        = string
  default     = ""
}

variable "create_efs" {
  description = "Create EFS for Appian shared folder requirements; should be set to false if building Appian in a single host configuration, which has no shared folder requirements."
  type        = bool
  default     = true
}

variable "efs_provisioned_throughput" {
  description = "Provisioned througput in MB/s of Appian's EFS."
  type        = string
  default     = "50"
}

variable "efs_subnets" {
  description = "The subnets where EFS mount targets will be created.  You must create one and only one mount target for each availability zone that contains an Appian.  If your Appian's are in separate subnets and each subnet is in a separate AZ, then this is simply a list of all appian_instances subnets.  Required if create_efs is true."
  type        = list
  default     = []
}


variable "appian_instances_key" {
  description = "EC2 key pair to associate with the launched appian instances."
  type        = string
  default     = ""
}

variable "appian_instances_ami" {
  description = "ID of the ami for the appian instances"
  type        = string
}

variable "appian_instances" {
  description = "A map containing information about the appian instances and topology."
  type = map(object({
    instance_type = string
    subnet_id     = string
    roles         = list(string)
  }))
  # Variable validation would be very helpful here... It's current experimental
  # I'm going to leave it out for now, because not everyone will have it enabled
}

variable "appian_environment" {
  description = "This is a tag applied to most resources.  This tag and its value can be used later to find resources (if you're going to run ansible to configure appian, you will want to remember this value)"
  type        = string
}
