output "appian_host_security_group" {
  description = "The security group attached to the EC2 Appian Host.  This can be used to attach new rules outside the module."
  value       = aws_security_group.appian.id
}

output "appiands_security_group" {
  description = "The security group attached to the RDS serving as the Appian system data store.  This will not have a value if you brought your own RDS system data store instead of having the module build it for you."
  value       = var.create_new_db == true ? aws_security_group.appiands[0].id : ""
}

output "appian_host_role" {
  description = "The Appian EC2 instance(s) host role.  This can be used to attach additional policies externally."
  value       = aws_iam_role.appian_host.name
}

output "efs_id" {
  description = "ID of the EFS created for Appian's shared folder needs."
  value       = var.create_efs == true ? aws_efs_file_system.efs[0].id : ""
}
