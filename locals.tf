locals {
  protocol_number = {
    icmp   = 1
    icmpv6 = 58
    tcp    = 6
    udp    = 17
  }

  shapes = {
    flex : "VM.Standard.A1.Flex",
    micro : "VM.Standard.E2.1.Micro",
  }

  availability_domain_micro = one(
    [
      for m in data.oci_core_shapes.this :
      m.availability_domain
      if contains(m.shapes[*].name, local.shapes.micro)
    ]
  )

  user_data = {
    this : {
      runcmd : ["apt remove --assume-yes --purge apparmor"]
    },
    that : {
      runcmd : ["grubby --args selinux=0 --update-kernel ALL"]
    },
  }
}
