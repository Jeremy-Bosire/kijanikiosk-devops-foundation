variable "environment" {
  description = "Deployment environment name. Used in VM labels and naming."
  type        = string
}

variable "region" {
  description = "Logical region label for the environment. Multipass has no regions, so this is written to each VM's labels; on the cloud path it maps to the provider region."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for every VM name, e.g. kijanikiosk -> kijanikiosk-api."
  type        = string
}

variable "ubuntu_image" {
  description = "Multipass image alias to launch. 22.04 = Ubuntu Jammy LTS. The exact image hash is resolved at launch and exposed as an output."
  type        = string
}

variable "instance_types" {
  description = "Named size profiles (the Multipass equivalent of cloud instance types). Sizes use whole G units so the provider's drift check compares cleanly."
  type = map(object({
    cpus   = number
    memory = string
    disk   = string
  }))
}

variable "servers" {
  description = "Servers to provision, keyed by role. Each entry picks an instance_types profile."
  type = map(object({
    instance_type = string
  }))

  validation {
    condition     = length(var.servers) > 0
    error_message = "At least one server must be defined."
  }
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair in ~/.ssh (public half = <name>.pub). Must match ansible_ssh_private_key_file in ansible/group_vars/kijanikiosk.yml; pipeline.sh checks this."
  type        = string
}

variable "ssh_user" {
  description = "Login user created by the Ubuntu image and used by Ansible."
  type        = string
}

variable "admin_cidrs" {
  description = "Networks allowed to reach SSH (port 22). Applied as a boot-time host firewall - the Multipass equivalent of a cloud security group. Never 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "admin_cidrs must not contain 0.0.0.0/0 - SSH is never opened to the internet."
  }
}

variable "cloudinit_dir" {
  description = "Directory (relative to the terraform folder) where rendered cloud-init files are written before launch."
  type        = string
}
