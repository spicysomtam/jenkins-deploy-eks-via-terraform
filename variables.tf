#
# Variables Configuration
#

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "eu-west-1"
}

variable "cluster-name" {
  description = "EKS cluster name."
  default     = "demo"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version."
  default     = "1.17"
  type        = string
}


# Assumption; vpc is n.n.h.h/16; eg first 2 octets.
# Subnets for vpc's use tf counts and will increment the 3rd octet and set the subnet to /24 (eg n.n.0.h/24)
# See also vpc_subnets

variable "vpc-network" {
  description = "vpc cidr network portion; eg 10.0 for 10.0.0.0/16."
  default     = "10.0"
  type        = string
}

variable "vpc-subnets" {
  description = "vpc number of subnets/az's."
  default     = "3"
  type        = string
}

variable "inst-type" {
  description = "EKS worker instance type."
  default     = "m5.large"
  type        = string
}

# I bumped this up as 20Gb is way to small for all those docker images that will be pulled.
variable "inst_disk_size" {
  description = "EKS worker instance disk size in Gb."
  default     = "60"
  type        = string
}

variable "inst_key_pair" {
  description = "EKS worker instance ssh key pair."
  default     = "spicysomtam-aws4"
  type        = string
}

variable "num-workers" {
  description = "Number of eks worker instances to deploy."

  #  default = "3"
  default = "1"
  type    = string
}

variable "cloudwatch" {
  type    = bool 
  default = true
  description = "Install Cloudwatch logging, metrics and Container Insights."
}

variable "ca" {
  type    = bool 
  default = false
  description = "Install k8s Cluster Autoscaler."
}
