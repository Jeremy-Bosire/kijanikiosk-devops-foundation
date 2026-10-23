locals {
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    ssh_public_key = var.ssh_public_key
    admin_cidrs    = var.admin_cidrs
    labels         = var.labels
  })

  # The content hash is part of the file name. The Multipass provider only
  # tracks the cloud-init *path*, so without this a changed key or firewall rule
  # would silently not reach the VM. With it, a content change = new path =
  # planned replacement, which Terraform shows openly in the plan.
  cloud_init_path = "${var.cloudinit_dir}/${var.name}-${substr(sha256(local.cloud_init), 0, 12)}.yaml"
}

resource "local_file" "cloud_init" {
  filename        = local.cloud_init_path
  content         = local.cloud_init
  file_permission = "0644"
}

resource "multipass_instance" "this" {
  name           = var.name
  image          = var.image
  cpus           = var.cpus
  memory         = var.memory
  disk           = var.disk
  cloudinit_file = local_file.cloud_init.filename
}

# Read the VM back after launch: the IP is discovered, never typed in.
data "multipass_instance" "this" {
  name = multipass_instance.this.name
}
