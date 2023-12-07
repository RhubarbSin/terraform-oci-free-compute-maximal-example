resource "oci_identity_compartment" "this" {
  compartment_id = var.tenancy_ocid
  description    = var.name
  name           = replace(var.name, " ", "-")

  enable_delete = true
}

resource "oci_core_vcn" "this" {
  compartment_id = oci_identity_compartment.this.id

  cidr_blocks  = [var.cidr_block]
  display_name = var.name
  dns_label    = "vcn"
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = oci_identity_compartment.this.id
  vcn_id         = oci_core_vcn.this.id

  display_name = oci_core_vcn.this.display_name
}

resource "oci_core_default_route_table" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id

  display_name = oci_core_vcn.this.display_name

  route_rules {
    network_entity_id = oci_core_internet_gateway.this.id

    description = "Default route"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id

  dynamic "ingress_security_rules" {
    for_each = [22, 80, 443]
    iterator = port
    content {
      protocol = local.protocol_number.tcp
      source   = "0.0.0.0/0"

      description = "SSH and HTTPS traffic from any origin"

      tcp_options {
        max = port.value
        min = port.value
      }
    }
  }

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"

    description = "All traffic to any destination"
  }
}

resource "oci_core_subnet" "this" {
  cidr_block     = oci_core_vcn.this.cidr_blocks.0
  compartment_id = oci_identity_compartment.this.id
  vcn_id         = oci_core_vcn.this.id

  display_name = oci_core_vcn.this.display_name
  dns_label    = "subnet"
}

resource "oci_core_network_security_group" "this" {
  compartment_id = oci_identity_compartment.this.id
  vcn_id         = oci_core_vcn.this.id

  display_name = oci_core_vcn.this.display_name
}

resource "oci_core_network_security_group_security_rule" "this" {
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.this.id
  protocol                  = local.protocol_number.icmp
  source                    = "0.0.0.0/0"
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_shapes" "this" {
  for_each = toset(data.oci_identity_availability_domains.this.availability_domains[*].name)

  compartment_id = var.tenancy_ocid

  availability_domain = each.key
}

data "oci_core_images" "this" {
  compartment_id = oci_identity_compartment.this.id

  operating_system = "Canonical Ubuntu"
  shape            = local.shapes.micro
  sort_by          = "TIMECREATED"
  sort_order       = "DESC"
  state            = "available"

  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-([\\.0-9-]+)$"]
    regex  = true
  }
}

data "cloudinit_config" "this" {
  part {
    content = file("user-data-this.yaml")
  }
}

resource "oci_core_instance" "this" {
  count = 2

  availability_domain = local.availability_domain_micro
  compartment_id      = oci_identity_compartment.this.id
  shape               = local.shapes.micro

  display_name         = format("Ubuntu %d", count.index + 1)
  preserve_boot_volume = false

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.cloudinit_config.this.rendered
  }

  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }

  availability_config {
    is_live_migration_preferred = null
  }

  create_vnic_details {
    display_name   = format("Ubuntu %d", count.index + 1)
    hostname_label = format("ubuntu-%d", count.index + 1)
    nsg_ids        = [oci_core_network_security_group.this.id]
    subnet_id      = oci_core_subnet.this.id
  }

  source_details {
    source_id               = data.oci_core_images.this.images.0.id
    source_type             = "image"
    boot_volume_size_in_gbs = 50
  }

  lifecycle {
    ignore_changes = [source_details.0.source_id]
  }
}

data "oci_core_images" "that" {
  compartment_id = oci_identity_compartment.this.id

  operating_system = "Oracle Linux"
  shape            = local.shapes.flex
  sort_by          = "TIMECREATED"
  sort_order       = "DESC"
  state            = "available"
}

data "cloudinit_config" "that" {
  part {
    content = file("user-data-that.yaml")
  }
}

resource "oci_core_instance" "that" {
  availability_domain = data.oci_identity_availability_domains.this.availability_domains.0.name
  compartment_id      = oci_identity_compartment.this.id
  shape               = local.shapes.flex

  display_name         = "Oracle Linux"
  preserve_boot_volume = false

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.cloudinit_config.that.rendered
  }

  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }

  availability_config {
    is_live_migration_preferred = null
  }

  create_vnic_details {
    assign_public_ip = false
    display_name     = "Oracle Linux"
    hostname_label   = "oracle-linux"
    nsg_ids          = [oci_core_network_security_group.this.id]
    subnet_id        = oci_core_subnet.this.id
  }

  shape_config {
    memory_in_gbs = 24
    ocpus         = 4
  }

  source_details {
    source_id               = data.oci_core_images.that.images.0.id
    source_type             = "image"
    boot_volume_size_in_gbs = 100
  }

  lifecycle {
    ignore_changes = [source_details.0.source_id]
  }
}

data "oci_core_private_ips" "that" {
  ip_address = oci_core_instance.that.private_ip
  subnet_id  = oci_core_subnet.this.id
}

resource "oci_core_public_ip" "that" {
  compartment_id = oci_identity_compartment.this.id
  lifetime       = "RESERVED"

  display_name  = oci_core_instance.that.display_name
  private_ip_id = data.oci_core_private_ips.that.private_ips.0.id
}

resource "oci_core_volume_backup_policy" "this" {
  count = 3

  compartment_id = oci_identity_compartment.this.id

  display_name = format("Daily %d", count.index)

  schedules {
    backup_type       = "INCREMENTAL"
    hour_of_day       = count.index
    offset_type       = "STRUCTURED"
    period            = "ONE_DAY"
    retention_seconds = 86400
    time_zone         = "REGIONAL_DATA_CENTER_TIME"
  }
}

resource "oci_core_volume_backup_policy_assignment" "this" {
  count = 3

  asset_id = (
    count.index < 2 ?
    oci_core_instance.this[count.index].boot_volume_id :
    oci_core_instance.that.boot_volume_id
  )
  policy_id = oci_core_volume_backup_policy.this[count.index].id
}
