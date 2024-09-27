variable "tenancy_ocid" {
  description = "OCID of the tenancy"
  type        = string
  nullable    = false
}

variable "region" {
  description = "Region for resources"
  type        = string
  nullable    = false
}

variable "name" {
  description = "Display name for resources"
  type        = string
  nullable    = false
  default     = "OCI Free Compute Maximal"
}

variable "cidr_block" {
  description = "CIDR block of the VCN"
  type        = string
  default     = null

  validation {
    condition = (
      var.cidr_block == null ?
      true :
      alltrue(
        [
          can(cidrsubnet(var.cidr_block, 2, 0)),
          cidrhost(var.cidr_block, 0) == split("/", var.cidr_block).0,
        ]
      )
    )
    error_message = "The value of cidr_block variable must be a valid CIDR address with a prefix no greater than 30."
  }
}

variable "ssh_public_key" {
  description = "Public key to be used for SSH access to compute instances"
  type        = string
  nullable    = false
}
