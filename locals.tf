locals {
  protocol_number = {
    icmp   = 1
    icmpv6 = 58
    tcp    = 6
    udp    = 17
  }

  instance = {
    ubuntu = {
      shape : "VM.Standard.E2.1.Micro",
      operating_system = "Canonical Ubuntu",
      user_data : {
        runcmd : ["apt-get remove --quiet --assume-yes --purge apparmor"],
      },
    },
    oracle = {
      shape : "VM.Standard.A1.Flex",
      operating_system : "Oracle Linux",
      user_data : {
        runcmd : ["grubby --args selinux=0 --update-kernel ALL"],
      },
    },
  }
}
