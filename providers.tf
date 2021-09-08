#
# Provider Configuration
#
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.57.0"
    }

    # Not required: currently used in conjuction with using
    # icanhazip.com to determine local workstation external IP
    # to open EC2 Security Group access to the Kubernetes cluster.
    # See workstation-external-ip.tf for additional information.
    http = {
      source  = "hashicorp/http"
      version = "~> 2.1.0"
    }
  }
}

# Using these data sources allows the configuration to be
# generic for any region.
data "aws_region" "current" {
}

data "aws_availability_zones" "available" {
}
