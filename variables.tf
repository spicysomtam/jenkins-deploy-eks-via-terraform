#
# Variables Configuration
#

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "eu-west-1"
}

variable "cluster-name" {
  description = "EKS cluster name."
  default = "demo"
  type    = "string"
}

# Assumption; vpc is n.n.h.h/16; eg first 2 octets.
# Subnets for vpc's use tf counts and will increment the 3rd octet and set the subnet to /24 (eg n.n.0.h/24)
# See also vpc_subnets

variable "vpc-network" {
  description = "vpc cidr network portion; eg 10.0 for 10.0.0.0/16."
  default = "10.0"
  type    = "string"
}

variable "vpc-subnets" {
  description = "vpc number of subnets/az's."
  default = "3"
  type    = "string"
}

variable "inst-type" {
  description = "EKS worker instance type."
  default = "m4.large"
  type    = "string"
}

variable "num-workers" {
  description = "Number of eks worker instances to deploy."
#  default = "3"
  default = "1"
  type    = "string"
}

# Allowing access from everything is probably not secure; so please override this to your requirement.
variable "api-ingress-ips" {
  description = "External ips allowed access to k8s api."
  default = ["0.0.0.0/0"]
}
