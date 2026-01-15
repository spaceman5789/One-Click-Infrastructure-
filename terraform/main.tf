terraform {
  required_version = ">= 1.5.0"
}

variable "template_name" {
  type    = string
  default = "tmpl-ubuntu"
}

variable "app_name" {
  type    = string
  default = "app-vm"
}

variable "db_name" {
  type    = string
  default = "db-vm"
}

data "external" "utm" {
  program = ["bash", "${path.module}/../scripts/utm_ensure_vms.sh"]

  query = {
    TEMPLATE_NAME = var.template_name
    APP_NAME      = var.app_name
    DB_NAME       = var.db_name
  }
}

locals {
  app_ip = data.external.utm.result.app_ip
  db_ip  = data.external.utm.result.db_ip
}

resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<-EOT
  [app]
  ${local.app_ip} ansible_user=debian

  [db]
  ${local.db_ip} ansible_user=debian

  [all:vars]
  ansible_python_interpreter=/usr/bin/python3
  EOT
}

resource "null_resource" "destroy_hook" {
  triggers = {
    app = var.app_name
    db  = var.db_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "APP_NAME=${self.triggers.app} DB_NAME=${self.triggers.db} bash ${path.module}/../scripts/utm_destroy_vms.sh"
  }
}

output "app_ip" {
  value = local.app_ip
}

output "db_ip" {
  value = local.db_ip
}
