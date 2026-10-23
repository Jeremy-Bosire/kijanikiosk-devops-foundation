# All environment-specific values live here - none are hardcoded in resource blocks.

environment  = "staging"
region       = "ke-nairobi-local"
name_prefix  = "kijanikiosk"
ubuntu_image = "22.04"

instance_types = {
  tiny   = { cpus = 1, memory = "512M", disk = "5G" } # fits 3 VMs in a ~4 GB WSL
  small  = { cpus = 1, memory = "1G", disk = "5G" }
  medium = { cpus = 2, memory = "2G", disk = "8G" }
}

servers = {
  api      = { instance_type = "tiny" }
  payments = { instance_type = "tiny" }
  logs     = { instance_type = "tiny" }
}

ssh_key_name = "kijanikiosk_ed25519"
ssh_user     = "ubuntu"

# Private ranges only. Hyper-V's Default Switch (Windows) uses 172.16.0.0/12;
# Multipass on macOS uses 192.168.64.0/24; on Linux 10.x. Narrow this to your
# actual Multipass subnet once you know it (multipass list).
admin_cidrs = ["172.16.0.0/12", "192.168.0.0/16", "10.0.0.0/8"]

cloudinit_dir = ".generated"
