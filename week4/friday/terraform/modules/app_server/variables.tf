variable "name" {
  description = "Multipass VM name."
  type        = string
}

variable "role" {
  description = "Server role (api, payments, logs). Informational; carried in labels."
  type        = string
}

variable "image" {
  description = "Multipass image alias, e.g. 22.04."
  type        = string
}

variable "cpus" {
  description = "Number of virtual CPUs."
  type        = number
}

variable "memory" {
  description = "Memory size, e.g. 1G."
  type        = string
}

variable "disk" {
  description = "Disk size, e.g. 5G."
  type        = string
}

variable "ssh_public_key" {
  description = "OpenSSH public key installed for the default user at first boot."
  type        = string
}

variable "admin_cidrs" {
  description = "Networks allowed to reach SSH at first boot (host firewall, security-group equivalent)."
  type        = list(string)
}

variable "labels" {
  description = "Key/value labels written to /etc/kijanikiosk/node-labels on the VM."
  type        = map(string)
}

variable "cloudinit_dir" {
  description = "Directory where the rendered cloud-init file is written."
  type        = string
}
