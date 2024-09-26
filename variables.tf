variable "tenancy_ocid" {
  description = "OCID of the tenancy"
  type        = string
}

variable "name" {
  description = "Display name for resources"
  type        = string
  default     = "OCI Free Compute Maximal"
}

variable "cidr_block" {
  description = "CIDR block of the VCN"
  type        = string
  default     = null

  validation {
    condition     = var.cidr_block == null ? true : can(cidrsubnet(var.cidr_block, 2, 0))
    error_message = "The value of cidr_block variable must be a valid CIDR address with a prefix no greater than 30."
  }
}

variable "ssh_public_key" {
  description = "Public key to be used for SSH access to compute instances"
  type        = string
}
