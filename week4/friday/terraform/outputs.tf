output "server_ips" {
  description = "Map of role => IPv4 address, read from the multipass_instance data source."
  value       = { for role, s in module.app_server : role => s.ipv4 }
}

output "api_server_ip" {
  description = "IPv4 of the API server (for terraform output -raw)."
  value       = module.app_server["api"].ipv4
}

output "payments_server_ip" {
  description = "IPv4 of the payments server (for terraform output -raw)."
  value       = module.app_server["payments"].ipv4
}

output "logs_server_ip" {
  description = "IPv4 of the logs server (for terraform output -raw)."
  value       = module.app_server["logs"].ipv4
}

output "ssh_commands" {
  description = "Copy-paste SSH command for each server."
  value = {
    for role, s in module.app_server :
    role => "ssh -i ~/.ssh/${var.ssh_key_name} ${var.ssh_user}@${s.ipv4}"
  }
}

output "ansible_inventory" {
  description = "Ready-to-paste Ansible inventory body. pipeline.sh writes the same thing to ansible/inventory.ini."
  value = join("\n", concat(
    ["[kijanikiosk]"],
    [for role, s in module.app_server : "kk-${role} ansible_host=${s.ipv4}"],
  ))
}

output "vm_names" {
  description = "Map of role => Multipass VM name."
  value       = { for role, s in module.app_server : role => s.name }
}

output "image_hashes" {
  description = "Exact image hash each VM was launched from (the Multipass equivalent of a resolved AMI ID)."
  value       = { for role, s in module.app_server : role => s.image_hash }
}

output "ssh_key_name" {
  description = "Key pair name Terraform installed. pipeline.sh checks Ansible uses the same key."
  value       = var.ssh_key_name
}

output "admin_cidrs" {
  description = "Networks allowed to SSH. pipeline.sh checks Ansible's firewall uses the same list."
  value       = var.admin_cidrs
}
