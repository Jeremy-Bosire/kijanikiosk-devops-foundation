locals {
  # Public half of the key pair named by var.ssh_key_name. Reading it here (not
  # in the module) keeps the module free of any knowledge of the operator's disk.
  ssh_public_key = trimspace(file(pathexpand("~/.ssh/${var.ssh_key_name}.pub")))

  common_labels = {
    environment = var.environment
    region      = var.region
    managed_by  = "terraform"
  }
}

module "app_server" {
  source   = "./modules/app_server"
  for_each = var.servers

  name           = "${var.name_prefix}-${each.key}"
  role           = each.key
  image          = var.ubuntu_image
  cpus           = var.instance_types[each.value.instance_type].cpus
  memory         = var.instance_types[each.value.instance_type].memory
  disk           = var.instance_types[each.value.instance_type].disk
  ssh_public_key = local.ssh_public_key
  admin_cidrs    = var.admin_cidrs
  labels         = merge(local.common_labels, { role = each.key, instance_type = each.value.instance_type })
  cloudinit_dir  = "${path.root}/${var.cloudinit_dir}"
}
