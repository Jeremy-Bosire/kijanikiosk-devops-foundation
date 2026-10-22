output "name" {
  description = "Multipass VM name."
  value       = multipass_instance.this.name
}

output "ipv4" {
  description = "IPv4 address discovered via the multipass_instance data source."
  value       = data.multipass_instance.this.ipv4
}

output "image_hash" {
  description = "Hash of the image the VM was launched from."
  value       = data.multipass_instance.this.image_hash
}
