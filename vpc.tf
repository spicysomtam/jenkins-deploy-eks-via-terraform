#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "eks" {
  cidr_block = "${var.vpc-network}.0.0/16"

  tags = {
    "Name"                                          = "eks-${var.cluster-name}"
    "kubernetes.io/cluster/eks-${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "eks" {
  count = var.vpc-subnets

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = "${var.vpc-network}.${count.index}.0/24"
  vpc_id            = aws_vpc.eks.id
  map_public_ip_on_launch = true

  tags = {
    "Name"                                          = "eks-${var.cluster-name}"
    "kubernetes.io/cluster/eks-${var.cluster-name}" = "shared"
  }
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "eks-${var.cluster-name}"
  }
}

resource "aws_route_table" "eks" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }
}

resource "aws_route_table_association" "eks" {
  count = var.vpc-subnets

  subnet_id      = aws_subnet.eks[count.index].id
  route_table_id = aws_route_table.eks.id
}

