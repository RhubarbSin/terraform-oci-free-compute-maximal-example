terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 4.75.0"
    }
  }
}

provider "oci" {
  region = var.region
}
