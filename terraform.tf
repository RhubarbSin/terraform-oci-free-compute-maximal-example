terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.20.0"
    }
  }
}

provider "oci" {
  region = var.region
}
